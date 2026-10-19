Attribute VB_Name = "RefreshReport"
Option Explicit
'------------------------------------------------------------------
' BZME Insights | Weekly sales report automation
'
' HOW TO USE
' 1. Save a copy of Reporting_Automation_Portfolio.xlsx as a macro-enabled
'    workbook (.xlsm).
' 2. Press Alt+F11, choose File > Import File and select this .bas file.
' 3. Run RunWeeklyReport (Alt+F8). Pick the new POS export (CSV).
'
' WHAT IT DOES
' - Imports the CSV into Raw_Export as text, so dates and prices arrive
'   exactly as exported and the Clean sheet can standardise them.
' - Recalculates the workbook and moves the report week to the latest week.
' - Exports the Dashboard sheet as a dated PDF next to the workbook.
'
' CAPACITY: the Clean sheet holds formulas for 3,000 export rows.
'------------------------------------------------------------------
Private Const MAX_ROWS As Long = 3000

Public Sub RunWeeklyReport()
    Dim csvPath As Variant
    csvPath = Application.GetOpenFilename("CSV files (*.csv), *.csv", , "Select the POS export")
    If VarType(csvPath) = vbBoolean Then Exit Sub          'user cancelled

    Application.ScreenUpdating = False
    Application.Calculation = xlCalculationManual
    On Error GoTo CleanUp

    If Not ImportRawCsv(CStr(csvPath)) Then GoTo CleanUp
    Application.Calculation = xlCalculationAutomatic
    Application.CalculateFull
    SetLatestWeek
    Application.CalculateFull
    ExportDashboardPdf
    MsgBox "Report refreshed and exported." & vbCrLf & _
           "Check the data-quality log on the Dashboard before sending it.", vbInformation

CleanUp:
    Application.Calculation = xlCalculationAutomatic
    Application.ScreenUpdating = True
    If Err.Number <> 0 Then MsgBox "Something went wrong: " & Err.Description, vbExclamation
End Sub

Private Function ImportRawCsv(ByVal csvPath As String) As Boolean
    Dim wsRaw As Worksheet, wbCsv As Workbook, wsCsv As Worksheet
    Dim lastRow As Long, i As Long, fieldInfo(0 To 7) As Variant

    Set wsRaw = ThisWorkbook.Worksheets("Raw_Export")
    For i = 0 To 7: fieldInfo(i) = Array(i + 1, 2): Next i  'read every column as text

    Workbooks.OpenText Filename:=csvPath, Origin:=65001, StartRow:=1, _
        DataType:=xlDelimited, TextQualifier:=xlDoubleQuote, Comma:=True, FieldInfo:=fieldInfo
    Set wbCsv = ActiveWorkbook
    Set wsCsv = wbCsv.Worksheets(1)
    lastRow = wsCsv.Cells(wsCsv.Rows.Count, 1).End(xlUp).Row

    If lastRow - 1 > MAX_ROWS Then
        wbCsv.Close SaveChanges:=False
        MsgBox "The export has " & (lastRow - 1) & " rows; the workbook handles up to " & MAX_ROWS & ".", vbExclamation
        ImportRawCsv = False
        Exit Function
    End If

    wsRaw.Range("A2:H" & MAX_ROWS + 1).ClearContents
    wsRaw.Range("A2").Resize(lastRow - 1, 8).Value = wsCsv.Range("A2").Resize(lastRow - 1, 8).Value
    wbCsv.Close SaveChanges:=False
    ImportRawCsv = True
End Function

Private Sub SetLatestWeek()
    'Report on the most recent week found in the cleaned data
    ThisWorkbook.Worksheets("Assumptions").Range("B4").Value = _
        Application.WorksheetFunction.Max(ThisWorkbook.Worksheets("Clean").Range("M2:M" & MAX_ROWS + 1))
End Sub

Private Sub ExportDashboardPdf()
    Dim wk As Date, fileName As String
    wk = ThisWorkbook.Worksheets("Assumptions").Range("B4").Value
    fileName = ThisWorkbook.Path & Application.PathSeparator & "Weekly_Sales_Report_" & Format(wk, "yyyy-mm-dd") & ".pdf"
    ThisWorkbook.Worksheets("Dashboard").ExportAsFixedFormat Type:=xlTypePDF, fileName:=fileName, _
        Quality:=xlQualityStandard, OpenAfterPublish:=False
End Sub
