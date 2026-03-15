/*
 * eleeye_simple.cpp - Simple String-Based Interface for ElephantEye
 *
 * This file provides a simple interface that accepts UCCI commands as strings
 * and returns responses as strings, making it easy to integrate with Harbour.
 *
 * Includes both C++ implementation and Harbour bindings in one file.
 *
 * Author: Simplified for Harbour integration
 * Date: 2026-03-14
 */

#include <stdio.h>
#include <string.h>
#include <unistd.h>
#include <ctime>
#ifdef _WIN32
#include <io.h>
#include <direct.h>
#include <fcntl.h>
#else
#include <sys/stat.h>
#include <sys/types.h>
#include <fcntl.h>
#endif
#include "../base/base2.h"
#include "../base/parse.h"
#include "../base/pipe.h"
#include "ucci.h"
#include "pregen.h"
#include "position.h"
#include "hash.h"
#include "search.h"

// Harbour API headers
#include "hbapi.h"
#include "hbapiitm.h"
#include "hbvm.h"
#include "hbstack.h"

// Log level constants (must match xq_log.prg)
#define XQ_LOG_DEBUG   1
#define XQ_LOG_INFO    2
#define XQ_LOG_WARNING 3
#define XQ_LOG_ERROR   4
#define XQ_LOG_FATAL   5

// Memory buffer for stdout capture (cross-platform)
static char s_szStdoutBuffer[4096];
static size_t s_nStdoutBufferSize = sizeof(s_szStdoutBuffer);

static void WriteLogDirect( int nLevel, const char *szModule, const char *szMessage ) {
  // Try to call Harbour unified logging system
  PHB_DYNS pLogSym = hb_dynsymFind( "XQ_LOG_WRITEINTERNAL" );
  
  if (pLogSym) {
    // Push function symbol
    hb_vmPushDynSym( pLogSym );
    // Push NIL (required for function calls)
    hb_vmPushNil();
    // Push parameters: nLevel, cModule, cMessage
    hb_vmPushInteger( nLevel );
    hb_vmPushString( (char *)szModule, strlen( szModule ) );
    hb_vmPushString( (char *)szMessage, strlen( szMessage ) );
    // Execute function with 3 parameters
    hb_vmProc( 3 );
  }
  // If Harbour function not found, silently ignore
}

// Convenience macros for logging
#define LOG_DEBUG( mod, msg )   WriteLogDirect( XQ_LOG_DEBUG, mod, msg )
#define LOG_INFO( mod, msg )    WriteLogDirect( XQ_LOG_INFO, mod, msg )
#define LOG_WARNING( mod, msg ) WriteLogDirect( XQ_LOG_WARNING, mod, msg )
#define LOG_ERROR( mod, msg )   WriteLogDirect( XQ_LOG_ERROR, mod, msg )
#define LOG_FATAL( mod, msg )   WriteLogDirect( XQ_LOG_FATAL, mod, msg )

// Constants
const int INTERRUPT_COUNT = 4096;

// Static input buffer
static char s_szCommandBuffer[4096];
static int s_nCommandPos = 0;
static int s_nCommandLen = 0;

// Forward declarations
void BuildPos(PositionStruct &pos, const UcciCommStruct &UcciComm);
static UcciCommEnum SimpleIdleLine(UcciCommStruct &UcciComm, bool bDebug);
static void SetInput(const char *szInput);
static bool SimpleLineInput(char *szLine);

// Set input string
static void SetInput(const char *szInput) {
  strncpy(s_szCommandBuffer, szInput, sizeof(s_szCommandBuffer) - 1);
  s_szCommandBuffer[sizeof(s_szCommandBuffer) - 1] = '\0';
  s_nCommandLen = strlen(s_szCommandBuffer);
  s_nCommandPos = 0;
}

// Simulate line input
static bool SimpleLineInput(char *szLine) {
  if (s_nCommandPos >= s_nCommandLen) {
    return false;
  }

  // Find end of line
  int i = s_nCommandPos;
  while (i < s_nCommandLen && s_szCommandBuffer[i] != '\n') {
    i++;
  }

  // Copy line
  int nLen = i - s_nCommandPos;
  if (nLen > 0) {
    strncpy(szLine, s_szCommandBuffer + s_nCommandPos, nLen);
    szLine[nLen] = '\0';
  } else {
    szLine[0] = '\0';
  }

  // Skip newline
  s_nCommandPos = i + 1;

  return true;
}

// Parse idle line
static UcciCommEnum SimpleIdleLine(UcciCommStruct &UcciComm, bool bDebug) {
  char szLine[256];
  char *lp;
  bool bGoTime;

  while (!SimpleLineInput(szLine)) {
    // Wait for input
  }
  lp = szLine;

  // Parse commands (simplified version of IdleLine)
  if (false) {
  } else if (StrEqv(lp, "isready")) {
    return UCCI_COMM_ISREADY;
  } else if (StrEqvSkip(lp, "setoption ")) {
    // Simplified option parsing
    UcciComm.Option = UCCI_OPTION_UNKNOWN;
    return UCCI_COMM_SETOPTION;
  } else if (StrEqvSkip(lp, "position ")) {
    // Parse position directly
    static char szFen[256];
    if (StrEqvSkip(lp, "fen ")) {
      strcpy(szFen, lp);
      UcciComm.szFenStr = szFen;
    } else if (StrEqv(lp, "startpos")) {
      UcciComm.szFenStr = "rnbakabnr/9/1c5c1/p1p1p1p1p/9/9/P1P1P1P1P/1C5C1/9/RNBAKABNR w";
    }
    UcciComm.nMoveNum = 0;
    return UCCI_COMM_POSITION;
  } else if (StrEqvSkip(lp, "go ")) {
    UcciComm.bPonder = UcciComm.bDraw = false;
    bGoTime = false;
    if (false) {
    } else if (StrEqvSkip(lp, "depth ")) {
      UcciComm.Go = UCCI_GO_DEPTH;
      UcciComm.nDepth = Str2Digit(lp, 0, UCCI_MAX_DEPTH);
    } else {
      UcciComm.Go = UCCI_GO_DEPTH;
      UcciComm.nDepth = UCCI_MAX_DEPTH;
    }
    return UCCI_COMM_GO;
  } else if (StrEqv(lp, "stop")) {
    return UCCI_COMM_STOP;
  } else if (StrEqv(lp, "quit")) {
    return UCCI_COMM_QUIT;
  } else {
    return UCCI_COMM_UNKNOWN;
  }
}

// Initialize engine with string commands
extern "C" int ELEngine_InitString(void) {
  // Initialize pre-generated move tables
  PreGenInit();
  
  // Initialize hash table (16MB)
  NewHash(24);
  
  // Initialize position
  Search.pos.FromFen(cszStartFen);
  Search.pos.nDistance = 0;
  Search.pos.PreEvaluate();
  
  // Set default options
  Search.nBanMoves = 0;
  Search.bQuit = Search.bBatch = Search.bDebug = false;
  Search.bUseHash = Search.bUseBook = Search.bNullMove = Search.bKnowledge = true;
  Search.bIdle = false;
  Search.nCountMask = INTERRUPT_COUNT - 1;
  Search.nRandomMask = 0;
  Search.rc4Random.InitRand();
  
  // Set book file path
  LocatePath(Search.szBookFile, "BOOK.DAT");
  
  return 1;
}

// Helper function to extract bestmove from search output
static int ExtractBestMove(const char *szOutput, char *pBuffer, int nBufSize) {
  const char *pBest = strstr(szOutput, "bestmove");
  const char *pNoBest = strstr(szOutput, "nobestmove");
  
  if (pNoBest) {
    if (nBufSize > 10) {
      strcpy(pBuffer, "nobestmove");
      return 10;
    }
    return 0;
  }
  
  if (pBest) {
    // Extract bestmove (format: "bestmove c3c4" or "bestmove c3c4 ponder c9e7")
    pBest += 9; // Skip "bestmove "
    int i = 0;
    while (*pBest && *pBest != ' ' && *pBest != '\n' && i < 4 && i < nBufSize - 1) {
      pBuffer[i++] = *pBest++;
    }
    pBuffer[i] = '\0';
    return i;
  }
  
  // Error case
  if (nBufSize > 5) {
    strcpy(pBuffer, "error");
    return 5;
  }
  return 0;
}

// Process string command and return allocated buffer (4k)
extern "C" char* ELEngine_ProcessStringAlloc(const char *szInput) {
  LOG_INFO("eleEye_from_C", "ELEngine_ProcessStringAlloc called");
  
  // Allocate 4KB buffer using Harbour memory manager
  char *pBuffer = (char*) hb_xgrab(4096);
  pBuffer[0] = '\0';
  
  // Set input
  SetInput(szInput);
  
  // Process command
  UcciCommStruct UcciComm;
  UcciCommEnum comm = SimpleIdleLine(UcciComm, false);
  
  // Handle command
  switch (comm) {
    case UCCI_COMM_ISREADY:
      strncpy(pBuffer, "readyok", 4095);
      break;
      
    case UCCI_COMM_POSITION:
      BuildPos(Search.pos, UcciComm);
      Search.pos.nDistance = 0;
      Search.pos.PreEvaluate();
      strncpy(pBuffer, "position ok", 4095);
      break;
      
    case UCCI_COMM_GO:
      {
        // Use memory file (fmemopen) to capture stdout without leaving disk traces
        // This is faster and cleaner than temporary files
        FILE *fpOldStdout = NULL;
        FILE *fpMemStdout = NULL;
        
        // Clear memory buffer
        memset(s_szStdoutBuffer, 0, s_nStdoutBufferSize);
        
#ifdef _WIN32
        // Windows: fmemopen may not be available, use temp file approach
        fpOldStdout = freopen("eleeye_stdout.tmp", "w+b", stdout);
        if (fpOldStdout == NULL) {
          WriteLogDirect(XQ_LOG_ERROR, "eleEye_from_C", "Failed to freopen stdout");
          strncpy(pBuffer, "error: freopen failed", 4095);
          break;
        }
#else
        // Linux/Unix: use fmemopen for in-memory capture
        fpMemStdout = fmemopen(s_szStdoutBuffer, s_nStdoutBufferSize - 1, "w");
        if (fpMemStdout == NULL) {
          WriteLogDirect(XQ_LOG_ERROR, "eleEye_from_C", "Failed to fmemopen");
          strncpy(pBuffer, "error: fmemopen failed", 4095);
          break;
        }
        fpOldStdout = stdout;
        stdout = fpMemStdout;
#endif
        
        // Execute search
        Search.bPonder = UcciComm.bPonder;
        Search.bDraw = UcciComm.bDraw;
        Search.nGoMode = GO_MODE_INFINITY;
        Search.nNodes = 0;
        SearchMain(UcciComm.nDepth);
        
        // Flush stdout
        fflush(stdout);
        
        // Restore stdout
#ifdef _WIN32
        // Windows: close file and reopen NUL
        fclose(stdout);
        if (freopen("NUL", "w", stdout) == NULL) {
          // If reopening to NUL fails, stdout is now closed
          // This is OK for GUI applications
        }
#else
        // Linux/Unix: restore original stdout
        stdout = fpOldStdout;
        fclose(fpMemStdout);
#endif
        
        // Read captured output
#ifdef _WIN32
        // Windows: read from temp file
        FILE *fpTemp = fopen("eleeye_stdout.tmp", "rb");
        if (fpTemp == NULL) {
          WriteLogDirect(XQ_LOG_ERROR, "eleEye_from_C", "Failed to reopen temp file");
          strncpy(pBuffer, "error: reopen temp file failed", 4095);
          break;
        }
        size_t nRead = fread(pBuffer, 1, 4095, fpTemp);
        fclose(fpTemp);
        _unlink("eleeye_stdout.tmp");  // Clean up temp file
        if (nRead > 0) {
          pBuffer[nRead] = '\0';
        } else {
          pBuffer[0] = '\0';
        }
#else
        // Linux/Unix: read from memory buffer
        size_t nLen = strlen(s_szStdoutBuffer);
        if (nLen > 0 && nLen < 4095) {
          strncpy(pBuffer, s_szStdoutBuffer, 4095);
          pBuffer[nLen] = '\0';
        } else {
          pBuffer[0] = '\0';
        }
#endif
        
        // Debug: log captured output (show only first line to avoid multi-line log entries)
        char szDebugMsg[512];
        char *pFirstLine = pBuffer;
        char *pNewline = strchr(pBuffer, '\n');
        if (pNewline) {
          *pNewline = '\0';  // Terminate at first newline
          snprintf(szDebugMsg, sizeof(szDebugMsg), "Captured output (%zu bytes): %s", strlen(pBuffer), pFirstLine);
          *pNewline = '\n';  // Restore newline
        } else {
          snprintf(szDebugMsg, sizeof(szDebugMsg), "Captured output (%zu bytes): %s", strlen(pBuffer), pBuffer);
        }
        LOG_INFO("eleEye_from_C", szDebugMsg);

        // Extract bestmove and write to allocated buffer
        ExtractBestMove(pBuffer, pBuffer, 4095);

        // Debug: log extracted result
        snprintf(szDebugMsg, sizeof(szDebugMsg), "Extracted result: %s", pBuffer);
        LOG_INFO("eleEye_from_C", szDebugMsg);
      }
      break;
      
    case UCCI_COMM_STOP:
      strncpy(pBuffer, "nobestmove", 4095);
      break;
      
    default:
      strncpy(pBuffer, "unknown command", 4095);
      break;
  }
  
  return pBuffer;  // Return pointer, Harbour will free it with hb_retc_buffer()
}

// Cleanup
extern "C" void ELEngine_CleanupString(void) {
  DelHash();
}

//--------------------------------------------------------------------------------
// Harbour callable functions
//--------------------------------------------------------------------------------

// ELEngine_InitString() -> nResult (1=success, 0=failure)
HB_FUNC( ELENGINE_INITSTRING )
{
  int nResult = ELEngine_InitString();
  hb_retni( nResult );
}

// ELEngine_ProcessString(cCommands) -> cResult
// Process command and return result (Harbour will auto-free the memory)
HB_FUNC( ELENGINE_PROCESSSTRING )
{
  PHB_ITEM cCommands = hb_param( 1, HB_IT_STRING );

  if( cCommands )
  {
    const char* szCommands = hb_itemGetC( cCommands );
    char* szResult = ELEngine_ProcessStringAlloc( szCommands );
    hb_retc_buffer( szResult );  // 返回并自动释放内存
  }
  else
  {
    hb_retc( "" );
  }
}

// ELEngine_CleanupString() -> NIL
HB_FUNC( ELENGINE_CLEANUPSTRING )
{
  ELEngine_CleanupString();
  hb_ret();
}
