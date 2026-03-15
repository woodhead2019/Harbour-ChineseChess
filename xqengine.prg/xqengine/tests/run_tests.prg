/*
 * run_tests.prg
 * XQEngine 自动化测试运行器
 *
 * 功能:
 * - 自动发现和运行所有测试
 * - 生成测试报告
 * - 支持命令行参数
 *
 * 使用方法:
 *   hbmk2 run_tests.hbp
 *   ./run_tests                    # 运行所有测试
 *   ./run_tests --save             # 保存报告到文件
 *   ./run_tests --skip-integration # 跳过集成测试
 */

#include "hbclass.ch"
#include "xqengine_constants.ch"

// ============================================================================
// 全局变量
// ============================================================================

STATIC s_lSkipIntegration := .F.

// ============================================================================
// 主程序
// ============================================================================

PROCEDURE Main( ... )

   LOCAL aArgs := HB_AParams()
   LOCAL oSuite
   LOCAL lSaveReport := .F.
   LOCAL i

   ? "========================================"
   ? "XQEngine Automated Test Runner"
   ? "========================================"
   ?

   // 解析命令行参数
   FOR i := 1 TO Len( aArgs )
      DO CASE
      CASE Lower( aArgs[i] ) == "--save" .OR. Lower( aArgs[i] ) == "-s"
         lSaveReport := .T.
      CASE Lower( aArgs[i] ) == "--skip-integration"
         s_lSkipIntegration := .T.
      CASE Lower( aArgs[i] ) == "--help" .OR. Lower( aArgs[i] ) == "-h"
         XQECI_Info( XQECI_MODULE_TEST, "Usage: run_tests [options]" )
         XQECI_Info( XQECI_MODULE_TEST, "" )
         XQECI_Info( XQECI_MODULE_TEST, "Options:" )
         XQECI_Info( XQECI_MODULE_TEST, "  --save              Save report to file" )
         XQECI_Info( XQECI_MODULE_TEST, "  --skip-integration  Skip integration tests" )
         XQECI_Info( XQECI_MODULE_TEST, "  --help              Show this help" )
         RETURN
      ENDCASE
   NEXT

   // 创建测试套件
   oSuite := XQTestSuite():New( "XQEngine Test Suite" )

   // 添加所有测试
   XQECI_Info( XQECI_MODULE_TEST, "Discovering tests..." )
   RegisterAllTests( oSuite )
   XQECI_Info( XQECI_MODULE_TEST, "" )

   // 运行测试
   oSuite:Run()

   // 保存报告
   IF lSaveReport
      oSuite:SaveReport( "test_report.txt" )
   ENDIF

   // 返回退出码
   IF oSuite:nFailed > 0 .OR. oSuite:nErrors > 0
      ErrorLevel( 1 )
   ELSE
      ErrorLevel( 0 )
   ENDIF

   RETURN

// ============================================================================
// 注册所有测试
// ============================================================================

PROCEDURE RegisterAllTests( oSuite )

   // === 单元测试 ===
   XQECI_Info( XQECI_MODULE_TEST, "  - EngineConfig tests" )
   oSuite:AddTestCase( Create_ConfigTests() )

   XQECI_Info( XQECI_MODULE_TEST, "  - EngineConfig Validation tests" )
   oSuite:AddTestCase( Create_ConfigValidationTests() )

   XQECI_Info( XQECI_MODULE_TEST, "  - EngineState tests" )
   oSuite:AddTestCase( Create_EngineStateTests() )

   XQECI_Info( XQECI_MODULE_TEST, "  - UCI Protocol tests" )
   oSuite:AddTestCase( Create_UCIProtocolTests() )

   XQECI_Info( XQECI_MODULE_TEST, "  - UCCI Protocol tests" )
   oSuite:AddTestCase( Create_UCCIProtocolTests() )

   XQECI_Info( XQECI_MODULE_TEST, "  - GoParams tests" )
   oSuite:AddTestCase( Create_GoParamsTests() )

   XQECI_Info( XQECI_MODULE_TEST, "  - XQEngine Core tests" )
   oSuite:AddTestCase( Create_XQEngineTests() )

   XQECI_Info( XQECI_MODULE_TEST, "  - ErrorSystem tests" )
   oSuite:AddTestCase( Create_ErrSysTests() )

   XQECI_Info( XQECI_MODULE_TEST, "  - Protocol Parse tests" )
   oSuite:AddTestCase( Create_ProtocolParseTests() )

   // === 集成测试（需要实际引擎）===
   IF !s_lSkipIntegration
      XQECI_Info( XQECI_MODULE_TEST, "  - Integration tests (requires engine)" )
      oSuite:AddTestCase( Create_IntegrationTests() )

      XQECI_Info( XQECI_MODULE_TEST, "  - Analyze tests (requires engine)" )
      oSuite:AddTestCase( Create_AnalyzeTests() )

      XQECI_Info( XQECI_MODULE_TEST, "  - Search tests (requires engine)" )
      oSuite:AddTestCase( Create_SearchTests() )

      XQECI_Info( XQECI_MODULE_TEST, "  - Async tests (requires engine)" )
      oSuite:AddTestCase( Create_AsyncTests() )

      XQECI_Info( XQECI_MODULE_TEST, "  - NNUE tests (requires engine)" )
      oSuite:AddTestCase( Create_NNUETests() )

      XQECI_Info( XQECI_MODULE_TEST, "  - EdgeCase tests (requires engine)" )
      oSuite:AddTestCase( Create_EdgeCaseTests() )
   ELSE
      XQECI_Info( XQECI_MODULE_TEST, "  - Integration tests: SKIPPED" )
   ENDIF

   RETURN
