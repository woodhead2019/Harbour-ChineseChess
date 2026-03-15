/*
 * xqengine_test.prg
 * XQEngine 自动化测试框架
 *
 * 功能:
 * - 单元测试框架
 * - 自动发现和运行测试
 * - 测试报告生成
 * - 断言方法
 *
 * 使用方法:
 *   LOCAL oTest := XQTestCase():New( "MyTest" )
 *   oTest:SetMethod( "test_xxx", {|| ... } )
 *   oSuite:AddTestCase( oTest )
 *   oSuite:Run()
 */

#include "hbclass.ch"
#include "fileio.ch"

// ============================================================================
// 全局变量 - 必须在可执行代码之前
// ============================================================================

STATIC s_oSuite := NIL

// ============================================================================
// 测试结果常量
// ============================================================================

#define TEST_RESULT_PASS    1
#define TEST_RESULT_FAIL    2
#define TEST_RESULT_SKIP    3
#define TEST_RESULT_ERROR   4

// ============================================================================
// XQTestResult 类 - 单个测试结果
// ============================================================================

CREATE CLASS XQTestResult

   VAR cTestName     INIT ""
   VAR nResult       INIT 0
   VAR cMessage      INIT ""
   VAR nDuration     INIT 0
   VAR cError        INIT ""

   METHOD New( cTestName )
   METHOD IsPass()
   METHOD IsFail()
   METHOD ToString()

ENDCLASS

METHOD New( cTestName ) CLASS XQTestResult
   ::cTestName := cTestName
   RETURN Self

METHOD IsPass() CLASS XQTestResult
   RETURN ::nResult == TEST_RESULT_PASS

METHOD IsFail() CLASS XQTestResult
   RETURN ::nResult == TEST_RESULT_FAIL .OR. ::nResult == TEST_RESULT_ERROR

METHOD ToString() CLASS XQTestResult
   LOCAL cResult := "["
   cResult += iif( ::nResult == TEST_RESULT_PASS, "PASS", ;
              iif( ::nResult == TEST_RESULT_FAIL, "FAIL", ;
              iif( ::nResult == TEST_RESULT_SKIP, "SKIP", "ERROR" ) ) )
   cResult += "] " + ::cTestName
   IF !Empty( ::cMessage )
      cResult += " - " + ::cMessage
   ENDIF
   IF !Empty( ::cError )
      cResult += " (" + ::cError + ")"
   ENDIF
   cResult += " [" + hb_ntos( ::nDuration ) + "ms]"
   RETURN cResult

// ============================================================================
// XQTestCase 类 - 测试用例
// ============================================================================

CREATE CLASS XQTestCase

   VAR cName         INIT ""
   VAR aMethods      INIT {}
   VAR bSetup        INIT NIL
   VAR bTearDown     INIT NIL
   VAR lSkip         INIT .F.
   VAR cSkipReason   INIT ""
   VAR aResults      INIT {}

   METHOD New( cName )
   METHOD SetMethod( cName, bMethod )
   METHOD Setup( bBlock )
   METHOD TearDown( bBlock )
   METHOD Skip( cReason )
   METHOD Run()
   METHOD RunMethod( cName, bMethod )

ENDCLASS

METHOD New( cName ) CLASS XQTestCase
   ::cName := cName
   ::aMethods := {}
   ::aResults := {}
   RETURN Self

METHOD SetMethod( cName, bMethod ) CLASS XQTestCase
   IF HB_ISSTRING( cName ) .AND. HB_ISBLOCK( bMethod )
      AAdd( ::aMethods, { cName, bMethod } )
   ENDIF
   RETURN Self

METHOD Setup( bBlock ) CLASS XQTestCase
   ::bSetup := bBlock
   RETURN Self

METHOD TearDown( bBlock ) CLASS XQTestCase
   ::bTearDown := bBlock
   RETURN Self

METHOD Skip( cReason ) CLASS XQTestCase
   ::lSkip := .T.
   ::cSkipReason := iif( HB_ISSTRING( cReason ), cReason, "No reason" )
   RETURN Self

METHOD Run() CLASS XQTestCase
   LOCAL i, cName, bMethod, oResult

   IF ::lSkip
      oResult := XQTestResult():New( ::cName )
      oResult:nResult := TEST_RESULT_SKIP
      oResult:cMessage := ::cSkipReason
      AAdd( ::aResults, oResult )
      RETURN Self
   ENDIF

   IF HB_ISBLOCK( ::bSetup )
      BEGIN SEQUENCE
         Eval( ::bSetup )
      RECOVER USING oError
         FOR i := 1 TO Len( ::aMethods )
            oResult := XQTestResult():New( ::aMethods[i][1] )
            oResult:nResult := TEST_RESULT_ERROR
            oResult:cError := "Setup failed: " + oError:Description
            AAdd( ::aResults, oResult )
         NEXT
         RETURN Self
      END SEQUENCE
   ENDIF

   FOR i := 1 TO Len( ::aMethods )
      cName := ::aMethods[i][1]
      bMethod := ::aMethods[i][2]
      ::RunMethod( cName, bMethod )
   NEXT

   IF HB_ISBLOCK( ::bTearDown )
      BEGIN SEQUENCE
         Eval( ::bTearDown )
      RECOVER USING oError
         // TearDown 失败记录到最后一个结果
         IF Len( ::aResults ) > 0
            oResult := ::aResults[Len( ::aResults )]
            IF !Empty( oResult:cError )
               oResult:cError += "; TearDown failed: " + oError:Description
            ELSE
               oResult:cError := "TearDown failed: " + oError:Description
            ENDIF
         ENDIF
      END SEQUENCE
   ENDIF

   RETURN Self

METHOD RunMethod( cName, bMethod ) CLASS XQTestCase
   LOCAL oResult, nStart, oError

   oResult := XQTestResult():New( ::cName + "::" + cName )
   nStart := hb_MilliSeconds()

   BEGIN SEQUENCE
      Eval( bMethod )
      oResult:nResult := TEST_RESULT_PASS
      oResult:cMessage := "OK"
   RECOVER USING oError
      oResult:nResult := TEST_RESULT_FAIL
      oResult:cError := oError:Description
   END SEQUENCE

   oResult:nDuration := hb_MilliSeconds() - nStart
   AAdd( ::aResults, oResult )
   RETURN NIL

// ============================================================================
// XQTestSuite 类 - 测试套件
// ============================================================================

CREATE CLASS XQTestSuite

   VAR cName         INIT "XQEngine Test Suite"
   VAR aTestCases    INIT {}
   VAR nPassed       INIT 0
   VAR nFailed       INIT 0
   VAR nSkipped      INIT 0
   VAR nErrors       INIT 0
   VAR nStartTime    INIT 0
   VAR nEndTime      INIT 0
   VAR aAllResults   INIT {}

   METHOD New( cName )
   METHOD AddTestCase( oTestCase )
   METHOD Run()
   METHOD GetReport()
   METHOD PrintReport()
   METHOD SaveReport( cFileName )
   METHOD GetStats()

ENDCLASS

METHOD New( cName ) CLASS XQTestSuite
   IF HB_ISSTRING( cName )
      ::cName := cName
   ENDIF
   ::aTestCases := {}
   ::aAllResults := {}
   RETURN Self

METHOD AddTestCase( oTestCase ) CLASS XQTestSuite
   IF HB_ISOBJECT( oTestCase )
      AAdd( ::aTestCases, oTestCase )
   ENDIF
   RETURN Self

METHOD Run() CLASS XQTestSuite
   LOCAL i, oTestCase, j

   ::nStartTime := hb_MilliSeconds()
   ::nPassed := 0
   ::nFailed := 0
   ::nSkipped := 0
   ::nErrors := 0
   ::aAllResults := {}

   ? "========================================"
   ? "Running: " + ::cName
   ? "========================================"
   ?

   FOR i := 1 TO Len( ::aTestCases )
      oTestCase := ::aTestCases[i]
      ? "Running test case: " + oTestCase:cName + " ..."

      oTestCase:Run()

      FOR j := 1 TO Len( oTestCase:aResults )
         AAdd( ::aAllResults, oTestCase:aResults[j] )
         DO CASE
         CASE oTestCase:aResults[j]:IsPass()
            ::nPassed++
         CASE oTestCase:aResults[j]:nResult == TEST_RESULT_SKIP
            ::nSkipped++
         CASE oTestCase:aResults[j]:nResult == TEST_RESULT_ERROR
            ::nErrors++
         OTHERWISE
            ::nFailed++
         ENDCASE
      NEXT
   NEXT

   ::nEndTime := hb_MilliSeconds()
   ?
   ::PrintReport()
   RETURN Self

METHOD GetStats() CLASS XQTestSuite
   LOCAL oStats := { => }
   HB_HSet( oStats, "total", Len( ::aAllResults ) )
   HB_HSet( oStats, "passed", ::nPassed )
   HB_HSet( oStats, "failed", ::nFailed )
   HB_HSet( oStats, "skipped", ::nSkipped )
   HB_HSet( oStats, "errors", ::nErrors )
   HB_HSet( oStats, "duration", ::nEndTime - ::nStartTime )
   RETURN oStats

METHOD GetReport() CLASS XQTestSuite
   LOCAL cReport := ""
   LOCAL i, oResult

   cReport += "========================================" + hb_eol()
   cReport += "XQEngine Test Report" + hb_eol()
   cReport += "========================================" + hb_eol()
   cReport += hb_eol()
   cReport += "Summary:" + hb_eol()
   cReport += "  Total:   " + hb_ntos( Len( ::aAllResults ) ) + hb_eol()
   cReport += "  Passed:  " + hb_ntos( ::nPassed ) + hb_eol()
   cReport += "  Failed:  " + hb_ntos( ::nFailed ) + hb_eol()
   cReport += "  Skipped: " + hb_ntos( ::nSkipped ) + hb_eol()
   cReport += "  Errors:  " + hb_ntos( ::nErrors ) + hb_eol()
   cReport += "  Duration: " + hb_ntos( ::nEndTime - ::nStartTime ) + "ms" + hb_eol()
   cReport += hb_eol()

   IF ::nFailed > 0 .OR. ::nErrors > 0
      cReport += "Failed Tests:" + hb_eol()
      FOR i := 1 TO Len( ::aAllResults )
         oResult := ::aAllResults[i]
         IF oResult:IsFail()
            cReport += "  - " + oResult:ToString() + hb_eol()
         ENDIF
      NEXT
      cReport += hb_eol()
   ENDIF

   cReport += "All Tests:" + hb_eol()
   FOR i := 1 TO Len( ::aAllResults )
      oResult := ::aAllResults[i]
      cReport += "  " + oResult:ToString() + hb_eol()
   NEXT

   RETURN cReport

METHOD PrintReport() CLASS XQTestSuite
   ? ::GetReport()
   RETURN Self

METHOD SaveReport( cFileName ) CLASS XQTestSuite
   LOCAL nHandle

   IF Empty( cFileName )
      cFileName := "test_report_" + DToS( Date() ) + "_" + StrTran( Time(), ":", "" ) + ".txt"
   ENDIF

   nHandle := FCreate( cFileName )
   IF nHandle >= 0
      FWrite( nHandle, ::GetReport() )
      FClose( nHandle )
      ? "Report saved to: " + cFileName
   ENDIF
   RETURN Self

// ============================================================================
// XQAssert 类 - 断言工具
// ============================================================================

CREATE CLASS XQAssert

   METHOD Equal( xExpected, xActual, cMessage )
   METHOD NotEqual( xExpected, xActual, cMessage )
   METHOD IsTrue( lCondition, cMessage )
   METHOD IsFalse( lCondition, cMessage )
   METHOD IsNil( xValue, cMessage )
   METHOD NotNil( xValue, cMessage )
   METHOD IsEmpty( xValue, cMessage )
   METHOD NotEmpty( xValue, cMessage )
   METHOD Contains( cString, cSubstring, cMessage )
   METHOD IsType( xValue, cType, cMessage )
   METHOD InRange( nValue, nMin, nMax, cMessage )
   METHOD Fail( cMessage )

ENDCLASS

METHOD Equal( xExpected, xActual, cMessage ) CLASS XQAssert
   LOCAL cMsg := iif( HB_ISSTRING( cMessage ), cMessage, "Assert Equal" )
   IF !xExpected == xActual
      ::Fail( cMsg + ": expected [" + cValToChar( xExpected ) + "], got [" + cValToChar( xActual ) + "]" )
   ENDIF
   RETURN Self

METHOD NotEqual( xExpected, xActual, cMessage ) CLASS XQAssert
   LOCAL cMsg := iif( HB_ISSTRING( cMessage ), cMessage, "Assert Not Equal" )
   IF xExpected == xActual
      ::Fail( cMsg + ": values are equal [" + cValToChar( xExpected ) + "]" )
   ENDIF
   RETURN Self

METHOD IsTrue( lCondition, cMessage ) CLASS XQAssert
   LOCAL cMsg := iif( HB_ISSTRING( cMessage ), cMessage, "Assert True" )
   IF !lCondition
      ::Fail( cMsg + ": condition is false" )
   ENDIF
   RETURN Self

METHOD IsFalse( lCondition, cMessage ) CLASS XQAssert
   LOCAL cMsg := iif( HB_ISSTRING( cMessage ), cMessage, "Assert False" )
   IF lCondition
      ::Fail( cMsg + ": condition is true" )
   ENDIF
   RETURN Self

METHOD IsNil( xValue, cMessage ) CLASS XQAssert
   LOCAL cMsg := iif( HB_ISSTRING( cMessage ), cMessage, "Assert Nil" )
   IF xValue != NIL
      ::Fail( cMsg + ": value is not nil" )
   ENDIF
   RETURN Self

METHOD NotNil( xValue, cMessage ) CLASS XQAssert
   LOCAL cMsg := iif( HB_ISSTRING( cMessage ), cMessage, "Assert Not Nil" )
   IF xValue == NIL
      ::Fail( cMsg + ": value is nil" )
   ENDIF
   RETURN Self

METHOD IsEmpty( xValue, cMessage ) CLASS XQAssert
   LOCAL cMsg := iif( HB_ISSTRING( cMessage ), cMessage, "Assert Empty" )
   IF !Empty( xValue )
      ::Fail( cMsg + ": value is not empty" )
   ENDIF
   RETURN Self

METHOD NotEmpty( xValue, cMessage ) CLASS XQAssert
   LOCAL cMsg := iif( HB_ISSTRING( cMessage ), cMessage, "Assert Not Empty" )
   IF Empty( xValue )
      ::Fail( cMsg + ": value is empty" )
   ENDIF
   RETURN Self

METHOD Contains( cString, cSubstring, cMessage ) CLASS XQAssert
   LOCAL cMsg := iif( HB_ISSTRING( cMessage ), cMessage, "Assert Contains" )
   IF !(cSubstring $ cString)
      ::Fail( cMsg + ": substring not found" )
   ENDIF
   RETURN Self

METHOD IsType( xValue, cType, cMessage ) CLASS XQAssert
   LOCAL cMsg := iif( HB_ISSTRING( cMessage ), cMessage, "Assert Type" )
   LOCAL cActualType := ValType( xValue )
   IF !(cActualType == cType)
      ::Fail( cMsg + ": expected type [" + cType + "], got [" + cActualType + "]" )
   ENDIF
   RETURN Self

METHOD InRange( nValue, nMin, nMax, cMessage ) CLASS XQAssert
   LOCAL cMsg := iif( HB_ISSTRING( cMessage ), cMessage, "Assert Range" )
   IF !(nValue >= nMin .AND. nValue <= nMax)
      ::Fail( cMsg + ": value [" + hb_ntos( nValue ) + "] not in range [" + hb_ntos( nMin ) + "-" + hb_ntos( nMax ) + "]" )
   ENDIF
   RETURN Self

METHOD Fail( cMessage ) CLASS XQAssert
   LOCAL oError := ErrorNew()
   oError:description := cMessage
   oError:severity := 2
   Break( oError )
   RETURN Self

// ============================================================================
// 辅助函数
// ============================================================================

STATIC FUNCTION cValToChar( xValue )
   DO CASE
   CASE xValue == NIL
      RETURN "NIL"
   CASE HB_ISSTRING( xValue )
      RETURN xValue
   CASE HB_ISNUMERIC( xValue )
      RETURN hb_ntos( xValue )
   CASE HB_ISLOGICAL( xValue )
      RETURN iif( xValue, ".T.", ".F." )
   CASE HB_ISARRAY( xValue )
      RETURN "{array:" + hb_ntos( Len( xValue ) ) + "}"
   CASE HB_ISHASH( xValue )
      RETURN "{hash:" + hb_ntos( Len( xValue ) ) + "}"
   CASE HB_ISOBJECT( xValue )
      RETURN "{object}"
   OTHERWISE
      RETURN "{unknown}"
   ENDCASE

// ============================================================================
// 全局测试函数
// ============================================================================

FUNCTION xq_GetTestSuite()
   IF s_oSuite == NIL
      s_oSuite := XQTestSuite():New()
   ENDIF
   RETURN s_oSuite

FUNCTION xq_AddTest( oTestCase )
   xq_GetTestSuite():AddTestCase( oTestCase )
   RETURN NIL

FUNCTION xq_RunAllTests()
   RETURN xq_GetTestSuite():Run()

FUNCTION xq_GetTestReport()
   RETURN xq_GetTestSuite():GetReport()

FUNCTION xq_SaveTestReport( cFileName )
   RETURN xq_GetTestSuite():SaveReport( cFileName )

// ============================================================================
// 便捷断言函数
// ============================================================================

FUNCTION xq_AssertEqual( xExpected, xActual, cMessage )
   XQAssert():Equal( xExpected, xActual, cMessage )
   RETURN .T.

FUNCTION xq_AssertTrue( lCondition, cMessage )
   XQAssert():IsTrue( lCondition, cMessage )
   RETURN .T.

FUNCTION xq_AssertFalse( lCondition, cMessage )
   XQAssert():IsFalse( lCondition, cMessage )
   RETURN .T.

FUNCTION xq_AssertNotNil( xValue, cMessage )
   XQAssert():NotNil( xValue, cMessage )
   RETURN .T.

FUNCTION xq_AssertEmpty( xValue, cMessage )
   XQAssert():IsEmpty( xValue, cMessage )
   RETURN .T.

FUNCTION xq_AssertNotEmpty( xValue, cMessage )
   XQAssert():NotEmpty( xValue, cMessage )
   RETURN .T.

FUNCTION xq_AssertContains( cString, cSubstring, cMessage )
   XQAssert():Contains( cString, cSubstring, cMessage )
   RETURN .T.

// ============================================================================
// 超时等待函数（用于集成测试）
// ============================================================================

/*
 * xq_WaitWithTimeout( bCondition, nTimeoutMs, nIntervalMs )
 * 带超时的条件等待
 *
 * 参数:
 *   bCondition  - 条件代码块，返回 .T. 表示条件满足
 *   nTimeoutMs  - 超时时间（毫秒），默认 5000
 *   nIntervalMs - 检查间隔（毫秒），默认 100
 *
 * 返回:
 *   .T. 条件在超时前满足
 *   .F. 超时
 */
FUNCTION xq_WaitWithTimeout( bCondition, nTimeoutMs, nIntervalMs )
   LOCAL nStart, nElapsed

   IF !HB_ISBLOCK( bCondition )
      RETURN .F.
   ENDIF

   nTimeoutMs := iif( HB_ISNUMERIC( nTimeoutMs ) .AND. nTimeoutMs > 0, nTimeoutMs, 5000 )
   nIntervalMs := iif( HB_ISNUMERIC( nIntervalMs ) .AND. nIntervalMs > 0, nIntervalMs, 100 )

   nStart := hb_MilliSeconds()

   DO WHILE .T.
      IF Eval( bCondition )
         RETURN .T.
      ENDIF

      nElapsed := hb_MilliSeconds() - nStart
      IF nElapsed >= nTimeoutMs
         RETURN .F.
      ENDIF

      hb_idleSleep( nIntervalMs / 1000.0 )
   ENDDO

   RETURN .F.

/*
 * xq_GetEnginePath()
 * 获取引擎路径，优先使用环境变量
 *
 * 返回:
 *   引擎路径字符串
 */
FUNCTION xq_GetEnginePath()
   LOCAL cPath

   // 优先使用环境变量
   cPath := GetEnv( "XQENGINE_PATH" )
   IF !Empty( cPath ) .AND. File( cPath )
      RETURN cPath
   ENDIF

   // 默认路径
   IF File( "../pikafish" )
      RETURN "../pikafish"
   ENDIF

   // 尝试其他常见位置
   IF File( "./pikafish" )
      RETURN "./pikafish"
   ENDIF

   IF File( "/usr/local/bin/pikafish" )
      RETURN "/usr/local/bin/pikafish"
   ENDIF

   // 返回默认值，让测试失败时显示路径
   RETURN "../pikafish"

// ============================================================================
// 演示程序
// ============================================================================

PROCEDURE Demo_TestFramework()
   LOCAL oSuite, oTest

   ? "=== XQEngine Test Framework Demo ==="
   ?

   oSuite := XQTestSuite():New( "Demo Tests" )

   oTest := XQTestCase():New( "Basic Assertions" )
   oTest:SetMethod( "test_equal", {|| xq_AssertEqual( 1, 1, "1 should equal 1" ) } )
   oTest:SetMethod( "test_true", {|| xq_AssertTrue( .T., ".T. should be true" ) } )
   oTest:SetMethod( "test_false", {|| xq_AssertFalse( .F., ".F. should be false" ) } )
   oTest:SetMethod( "test_not_empty", {|| xq_AssertNotEmpty( "hello", "string should not be empty" ) } )
   oSuite:AddTestCase( oTest )

   oTest := XQTestCase():New( "Failing Tests" )
   oTest:SetMethod( "test_will_fail", {|| xq_AssertEqual( 1, 2, "This will fail" ) } )
   oSuite:AddTestCase( oTest )

   oTest := XQTestCase():New( "Skipped Tests" )
   oTest:Skip( "Feature not implemented yet" )
   oTest:SetMethod( "test_skip", {|| xq_AssertTrue( .T. ) } )
   oSuite:AddTestCase( oTest )

   oSuite:Run()
   oSuite:SaveReport( "demo_test_report.txt" )

   RETURN
