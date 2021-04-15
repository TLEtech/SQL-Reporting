/*

Scaleable, customizable report made to allow comparison of product sales
during special sales periods compared to normal periods. 

Manager requested this, and the result can be modified and re-used for 
different purposes. All you need to do is set the proper variables.
Utilize this in conjuction with BI software to add analysis and visualizations.

*/



DECLARE @SaleStart Date
DECLARE @SaleEnd Date
DECLARE @SaleKey Varchar(20)
SET @SaleStart = '2020-12-21' 	-- Date you want tracking to begin in 'YYYY-MM-DD' format
SET @SaleEnd = '2020-12-31' 	-- Date you want tracking to end in 'YYYY-MM-DD' format
SET @SaleKey = 'SaleVariable'	-- Indicator of the item special you want to track
DECLARE @MaxPeriods Int 		
SET @MaxPeriods = 10			-- Set the max amount of pre-sale periods to set. IE:
						-- If your sale lasts ten days, and you set this to 3, the report
						-- will gather the 30 days prior to the sale and seperate them into
						-- 10 day increments.


DECLARE @SaleKeys Table (ItemID VarChar(10), ItemDesc VarChar(50))
	INSERT INTO @SaleKeys
		SELECT [ItemID], [ItemDescription]
		FROM [Server].[Database].[dbo].[ItemSaleTable] -- Generic schema
		WHERE SaleKey = @SaleStart -- 

-- Here we will create a Weekdays table that will include all work days (days that are eligible for tracking)
-- for reference later. 
DECLARE @Weekdays Table ([Date] Date, [Day] Varchar(10))
		INSERT INTO @Weekdays
-- If your environment does not include built-in calendar/weekday referencing, like mine does not,
-- you may want to create a local calendar table. I will upload the query in a seperate file.
			SELECT [Date], [DayName] FROM [Server].[Database].[dbo].[CalendarTable]
-- Removing weekends, unless your place of employment hates the sales reps and requires weekend work.
			WHERE DayName NOT IN ('Saturday', 'Sunday')
-- Removing holidays.
			AND [IsHoliday] = 0
-- Setting a start year.
			AND [Year] > 2017


DECLARE @ReportDates Table ([Date] Date, [Day] Varchar(10), [PreSalePeriod] int)

-- Gets the count of workable days in the sale period in order to provide a reference point for 
-- the other periods of time to compare to the sale period
DECLARE @WeekdaysInSale Int
SET @WeekdaysInSale = (SELECT COUNT([Date]) FROM @Weekdays
						WHERE [Date] >= @SaleStart AND [Date] <=  @SaleEnd)
DECLARE @PreSalePeriodLength Int
SET @PreSalePeriodLength = (SELECT @WeekdaysInSale)

-- Important variable for the future loops
DECLARE @DateCutoff Date

-- Declare and set counter for amount of 'periods' we want to go back.
DECLARE @PreSaleCounter INT
SET @PreSaleCounter = 0

-- The first statement grabs the dates and weekdays for the sale period (0 value for PreSalePeriod)
IF @PreSaleCounter = 0
	BEGIN
		INSERT INTO @ReportDates
		SELECT TOP (SELECT @WeekdaysInSale)
		[Date], [Day], @PreSaleCounter
		FROM @WeekDays
		WHERE [Date] >= @SaleStart AND [Date] <= @SaleEnd
		ORDER BY [Date] DESC
		SET @DateCutoff = (SELECT TOP 1 [Date] FROM @ReportDates ORDER BY [Date] Asc)
		SET @PreSaleCounter = 1
	END

-- Begins grabbing report days while the @PreSaleCounter variable is equal to or less than
-- the @MaxPeriods variable we specified. After each iteration, add one to the @PreSaleCounter. 
-- After the @PreSaleCounter variable is greater than the @MaxPeriods, the loop breaks.
WHILE @PreSaleCounter <= @MaxPeriods
	BEGIN
		INSERT INTO @ReportDates
		SELECT TOP (SELECT @PreSalePeriodLength)
		[Date], [Day], @PreSaleCounter
		FROM @WeekDays
		WHERE [Date] < @DateCutoff
		ORDER BY [Date] DESC
		SET @DateCutoff = (SELECT TOP 1 [Date] FROM @ReportDates ORDER BY [Date] Asc)
		SET @PreSaleCounter = (@PreSaleCounter + 1)
	END

-- Creating Base Report Data Variable
DECLARE @ReportData_Base Table
		(SalePeriod Int, [SOCreateDate] date, [SOweekDay] Varchar(10), SOCreateTime varchar(15),
		InvcKey int, InvoiceID varchar(9), ItemKey int, ItemID Varchar(15), LongDesc Varchar(max),
		CustID Varchar(20), CustName Varchar(40), ExtAmt Money, UnitPrice Money, QtyShipped Int,
		SperID Varchar(12))

-- Create base data for final queries
INSERT INTO @ReportData_Base
SELECT	[BaseData1],
		[BaseData2],
		[BaseData3],
		[SOCreateDate]
FROM [Server].[Database].[dbo].[InvoiceLineTable] Rept
	LEFT JOIN @ReportDates ReportDates 
		ON Rept.[SOCreateDate] = ReportDates.[Date]
WHERE SOCreateDate IN (SELECT [Date] FROM @ReportDates)
	AND ItemID IN (SELECT ItemID FROM @SaleKeys)
ORDER BY SOCreateDate DESC


-- Final queries. Pipe this data into wherever you are making your report.
SELECT *
--INTO [dbo].[CustomReport_Base]
FROM @ReportData_Base
ORDER BY SOCreateDate DESC

SELECT SalePeriod,
		SUM(ExtAmt) AS SalePeriodSales,
		SUM(QtyShipped) SalePeriodQtyShipped,
		COUNT(DISTINCT InvcKey) AS SaleItemInvoicesMade,
		(SELECT TOP 1 [Date] FROM @ReportDates WHERE PreSalePeriod = Report.SalePeriod ORDER BY [Date] DESC) AS PeriodEndDate,
		(SELECT TOP 1 [Date] FROM @ReportDates WHERE PreSalePeriod = Report.SalePeriod ORDER BY [Date] ASC) AS PeriodStartDate
--INTO [dbo].[CustomReport_Summary]
FROM @ReportData_Base Report
WHERE ItemID IN (SELECT ItemID FROM @SaleKeys)
GROUP BY SalePeriod
ORDER BY SalePeriod ASC

SELECT *
--INTO [dbo].[CustomReport_Keys]
FROM @SaleKeys
