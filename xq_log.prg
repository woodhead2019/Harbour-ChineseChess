/*
 * xq_log.prg - Unified Logging System for Chinese Chess Project
 * Written by freexbase in 2026
 *
 * To the extent possible under law, the author(s) have dedicated all copyright
 * and related and neighboring rights to this software to the public domain worldwide.
 * This software is distributed without any warranty.
 *
 * You should have received a copy of the CC0 Public Domain Dedication along
 * with this software. If not, see <http://creativecommons.org/publicdomain/zero/1.0/>.
 *
 * Design Principles:
 * - English messages for developer readability and searchability
 * - Structured format with timestamp, level, and module
 * - Configurable output targets (file, stderr)
 * - Performance optimized with buffered writes
 * - Thread-safe for future multi-threading support
 *
 * Author: iFlow CLI
 * Date: 2026-03-15
 * Version: 1.0.0
 */

#include "xq_xiangqi.ch"

// ============================================================================
// Static Variables
// ============================================================================

// Log level names
STATIC s_aLogLevelNames := { "DEBUG", "INFO", "WARNING", "ERROR", "FATAL" }

// Buffer size for performance optimization
#define LOG_BUFFER_SIZE 4096
#define LOG_BUFFER_FLUSH_LINES 10

STATIC s_lInitialized := .F.
STATIC s_nLogLevel := LOG_LEVEL_INFO
STATIC s_nLogTargets := LOG_TARGET_FILE
STATIC s_nLogFileHandle := -1
STATIC s_cLogFile := ""

// Buffered write optimization
STATIC s_cBuffer := ""
STATIC s_nBufferLines := 0

// Module-specific log levels (hash table)
STATIC s_hModuleLevels := { => }

// ============================================================================
// Initialization and Cleanup
// ============================================================================

//--------------------------------------------------------------------------------
/**
 * Initialize the logging system
 *
 * @param nLogLevel   Minimum log level to output (default: LOG_LEVEL_INFO)
 * @param nTargets    Bit flags for output targets (default: LOG_TARGET_FILE)
 * @param cLogFile    Log file path (default: auto-generated in logs/ directory)
 *
 * @example
 * xq_Log_Init( LOG_LEVEL_DEBUG, LOG_TARGET_FILE, "debug.log" )
 * xq_Log_Init( LOG_LEVEL_INFO, LOG_TARGET_ALL, "" )
 */
PROCEDURE xq_Log_Init( par_nLogLevel, par_nTargets, par_cLogFile )
   LOCAL l_nLogLevel, l_nTargets, l_cLogFile

   // Set defaults if parameters are Nil
   l_nLogLevel := iif( HB_ISNUMERIC( par_nLogLevel ), par_nLogLevel, LOG_LEVEL_INFO )
   l_nTargets := iif( HB_ISNUMERIC( par_nTargets ), par_nTargets, LOG_TARGET_FILE )
   l_cLogFile := iif( HB_ISSTRING( par_cLogFile ), par_cLogFile, "" )

   // Validate parameters
   l_nLogLevel := iif( l_nLogLevel < LOG_LEVEL_DEBUG .OR. l_nLogLevel > LOG_LEVEL_FATAL, LOG_LEVEL_INFO, l_nLogLevel )
   l_nTargets := iif( l_nTargets == 0, LOG_TARGET_FILE, l_nTargets )

   s_nLogLevel := l_nLogLevel
   s_nLogTargets := l_nTargets

   // Initialize file output if enabled
   IF HB_BITAND( s_nLogTargets, LOG_TARGET_FILE ) != 0
      IF Empty( l_cLogFile )
         // Auto-generate filename with timestamp
         l_cLogFile := xq_Log_GenerateFileName()
      ENDIF

      s_cLogFile := l_cLogFile
      xq_Log_OpenFile()
   ENDIF

   s_lInitialized := .T.
   
   RETURN
//--------------------------------------------------------------------------------
/**
 * Generate auto log filename with timestamp
 *
 * @return Auto-generated log filename
 */
STATIC FUNCTION xq_Log_GenerateFileName()
   LOCAL cDateStr, cTimeStr

   cDateStr := StrTran( DToC(Date()), "/", "" )
   cTimeStr := StrTran( Time(), ":", "" )

   RETURN "logs/xq_" + cDateStr + "_" + cTimeStr + ".log"

//--------------------------------------------------------------------------------
/**
 * Open log file for writing
 */
STATIC PROCEDURE xq_Log_OpenFile()
   LOCAL l_cDirectory

   IF Empty( s_cLogFile )
      RETURN
   ENDIF

   // Extract directory path
   l_cDirectory := hb_FNameDir( s_cLogFile )

   // Create directory if it doesn't exist
   IF !Empty( l_cDirectory ) .AND. !hb_DirExists( l_cDirectory )
      hb_DirCreate( l_cDirectory )
   ENDIF

   // Open file (append mode if exists, create otherwise)
   IF File( s_cLogFile )
      s_nLogFileHandle := FOpen( s_cLogFile, 2 )  // Read/Write mode
      IF s_nLogFileHandle >= 0
         FSeek( s_nLogFileHandle, 0, 2 )  // Seek to end
      ENDIF
   ELSE
      s_nLogFileHandle := FCreate( s_cLogFile )
   ENDIF

   // Write header if file was just created
   IF s_nLogFileHandle >= 0 .AND. FSeek( s_nLogFileHandle, 0, 2 ) == 0
      xq_Log_WriteToFile( "========================================" )
      xq_Log_WriteToFile( "Chinese Chess - Log File" )
      xq_Log_WriteToFile( "Version: 1.0.0" )
      xq_Log_WriteToFile( "Build: " + _HBMK_BUILD_DATE_ + " " + _HBMK_BUILD_TIME_ )
      xq_Log_WriteToFile( "========================================" )
      xq_Log_WriteToFile( "" )
   ENDIF
RETURN

//--------------------------------------------------------------------------------
/**
 * Close log file and flush buffer
 */
PROCEDURE xq_Log_Close()
   xq_Log_FlushBuffer()

   IF s_nLogFileHandle >= 0
      FClose( s_nLogFileHandle )
      s_nLogFileHandle := -1
   ENDIF

   s_lInitialized := .F.
RETURN

//--------------------------------------------------------------------------------
/**
 * Flush buffered log entries to file
 */
STATIC PROCEDURE xq_Log_FlushBuffer()
   IF !Empty( s_cBuffer )
      xq_Log_WriteToFile( s_cBuffer )
      s_cBuffer := ""
      s_nBufferLines := 0
   ENDIF
RETURN

//--------------------------------------------------------------------------------
/**
 * Write string to log file
 *
 * @param cString String to write
 */
STATIC PROCEDURE xq_Log_WriteToFile( cString )
   IF s_nLogFileHandle >= 0
      FWrite( s_nLogFileHandle, cString + hb_eol() )
   ENDIF
RETURN

// ============================================================================
// Core Logging Functions
// ============================================================================

//--------------------------------------------------------------------------------
/**
 * Set module-specific log level
 *
 * @param cModule  Module name
 * @param nLevel   Log level for this module
 *
 * @example
 * xq_Log_SetModuleLevel( "ElephantEye", LOG_LEVEL_DEBUG )
 * xq_Log_SetModuleLevel( "UCCI", LOG_LEVEL_WARNING )
 */
PROCEDURE xq_Log_SetModuleLevel( cModule, nLevel )
   LOCAL l_cModule

   IF HB_ISSTRING( cModule ) .AND. !Empty( cModule )
      IF HB_ISNUMERIC( nLevel ) .AND. nLevel >= LOG_LEVEL_DEBUG .AND. nLevel <= LOG_LEVEL_FATAL
         l_cModule := Upper( cModule )
         // Direct assignment to hash table
         s_hModuleLevels[ l_cModule ] := nLevel
      ENDIF
   ENDIF
RETURN

//--------------------------------------------------------------------------------
/**
 * Get module-specific log level (or global level if not set)
 *
 * @param cModule  Module name
 * @return Log level for the module
 */
STATIC FUNCTION xq_Log_GetModuleLevel( cModule )
   LOCAL l_cModule, l_nLevel, l_lFound

   l_lFound := .F.

   IF HB_ISSTRING( cModule ) .AND. !Empty( cModule )
      l_cModule := Upper( cModule )
      BEGIN SEQUENCE WITH __BreakBlock()
         l_nLevel := s_hModuleLevels[ l_cModule ]
         IF HB_ISNUMERIC( l_nLevel )
            l_lFound := .T.
         ENDIF
      RECOVER
         // Key doesn't exist, use global level
      END SEQUENCE
   ENDIF

   RETURN iif( l_lFound, l_nLevel, s_nLogLevel )

//--------------------------------------------------------------------------------
/**
 * Internal core logging function (PUBLIC for C code access)
 *
 * @param nLevel   Log level
 * @param cModule  Module name
 * @param cMessage Log message
 */
PROCEDURE xq_Log_WriteInternal( nLevel, cModule, cMessage )
   LOCAL cLevelStr, cDateTime, cOutput, l_nModuleLevel
   LOCAL l_cNormalizedModule

   // Check if initialized
   IF !s_lInitialized
      RETURN
   ENDIF

   // Validate level
   IF nLevel < LOG_LEVEL_DEBUG .OR. nLevel > LOG_LEVEL_FATAL
      nLevel := LOG_LEVEL_INFO
   ENDIF

   // Check module-specific level
   l_nModuleLevel := xq_Log_GetModuleLevel( cModule )
   IF nLevel < l_nModuleLevel
      RETURN
   ENDIF

   // Validate module name
   IF !HB_ISSTRING( cModule )
      cModule := "UNKNOWN"
   ELSE
      l_cNormalizedModule := Upper( StrTran( cModule, " ", "_" ) )
      cModule := iif( Len( l_cNormalizedModule ) > 15, Left( l_cNormalizedModule, 15 ), l_cNormalizedModule )
   ENDIF

   // Get level name
   IF nLevel >= 1 .AND. nLevel <= Len( s_aLogLevelNames )
      cLevelStr := s_aLogLevelNames[ nLevel ]
   ELSE
      cLevelStr := "UNKN"
   ENDIF

   // Generate timestamp
   cDateTime := DToC(Date()) + " " + Time()

   // Format: YYYY-MM-DD HH:MM:SS [LEVEL] [MODULE] Message
   cOutput := cDateTime + " [" + cLevelStr + "] [" + PadR( cModule, 15 ) + "] " + cMessage

   // Write to stderr if enabled
   IF HB_BITAND( s_nLogTargets, LOG_TARGET_STDERR ) != 0
      OutErr( cOutput + hb_eol() )
   ENDIF

   // Write to file if enabled
   IF HB_BITAND( s_nLogTargets, LOG_TARGET_FILE ) != 0
      // Use buffering for performance
      IF Empty( s_cBuffer )
         s_cBuffer := cOutput
         s_nBufferLines := 1
      ELSE
         s_cBuffer += hb_eol() + cOutput
         s_nBufferLines += 1
      ENDIF

      // Flush buffer if it's full
      IF s_nBufferLines >= LOG_BUFFER_FLUSH_LINES .OR. Len( s_cBuffer ) >= LOG_BUFFER_SIZE
         xq_Log_FlushBuffer()
      ENDIF
   ENDIF

   // For FATAL level, flush immediately
   IF nLevel == LOG_LEVEL_FATAL
      xq_Log_FlushBuffer()
   ENDIF
RETURN

// ============================================================================
// Convenience Functions
// ============================================================================

//--------------------------------------------------------------------------------
/**
 * Log DEBUG level message
 *
 * @param cModule  Module name
 * @param cMessage Log message
 */
PROCEDURE xq_Log_Debug( cModule, cMessage )
   xq_Log_WriteInternal( LOG_LEVEL_DEBUG, cModule, cMessage )
RETURN

//--------------------------------------------------------------------------------
/**
 * Log INFO level message
 *
 * @param cModule  Module name
 * @param cMessage Log message
 */
PROCEDURE xq_Log_Info( cModule, cMessage )
   xq_Log_WriteInternal( LOG_LEVEL_INFO, cModule, cMessage )
RETURN

//--------------------------------------------------------------------------------
/**
 * Log WARNING level message
 *
 * @param cModule  Module name
 * @param cMessage Log message
 */
PROCEDURE xq_Log_Warning( cModule, cMessage )
   xq_Log_WriteInternal( LOG_LEVEL_WARNING, cModule, cMessage )
RETURN

//--------------------------------------------------------------------------------
/**
 * Log ERROR level message
 *
 * @param cModule  Module name
 * @param cMessage Log message
 */
PROCEDURE xq_Log_Error( cModule, cMessage )
   xq_Log_WriteInternal( LOG_LEVEL_ERROR, cModule, cMessage )
RETURN

//--------------------------------------------------------------------------------
/**
 * Log FATAL level message (auto-flushes buffer)
 *
 * @param cModule  Module name
 * @param cMessage Log message
 */
PROCEDURE xq_Log_Fatal( cModule, cMessage )
   xq_Log_WriteInternal( LOG_LEVEL_FATAL, cModule, cMessage )
RETURN

// ============================================================================
// Configuration Functions
// ============================================================================

//--------------------------------------------------------------------------------
/**
 * Set global log level
 *
 * @param nLevel Log level (LOG_LEVEL_DEBUG to LOG_LEVEL_FATAL)
 */
PROCEDURE xq_Log_SetLevel( nLevel )
   IF HB_ISNUMERIC( nLevel ) .AND. nLevel >= LOG_LEVEL_DEBUG .AND. nLevel <= LOG_LEVEL_FATAL
      s_nLogLevel := nLevel
   ENDIF
RETURN

//--------------------------------------------------------------------------------
/**
 * Get current global log level
 *
 * @return Current log level
 */
FUNCTION xq_Log_GetLevel()
   RETURN s_nLogLevel

//--------------------------------------------------------------------------------
/**
 * Set log output targets
 *
 * @param nTargets Bit flags (LOG_TARGET_FILE, LOG_TARGET_STDERR, etc.)
 */
PROCEDURE xq_Log_SetTargets( nTargets )
   IF HB_ISNUMERIC( nTargets )
      s_nLogTargets := nTargets
   ENDIF
RETURN

//--------------------------------------------------------------------------------
/**
 * Get current log file path
 *
 * @return Log file path
 */
FUNCTION xq_Log_GetFile()
   RETURN s_cLogFile

//--------------------------------------------------------------------------------
/**
 * Check if logging is initialized
 *
 * @return .T. if initialized, .F. otherwise
 */
FUNCTION xq_Log_IsInitialized()
   RETURN s_lInitialized

// ============================================================================
// End of xq_log.prg
// ============================================================================