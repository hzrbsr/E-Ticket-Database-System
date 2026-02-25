-- ============================================================
-- E-TICKET DATABASE FOR SQL SERVER (SSMS)
-- Comprehensive Electronic Ticketing System
-- ============================================================

-- Create Database
    



-- Create Schema for organization
IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = 'ticket')
BEGIN
    EXEC('CREATE SCHEMA ticket');
END
GO

-- ============================================================
-- 1. DROP EXISTING OBJECTS (CLEAN SETUP)
-- ============================================================

-- Drop Procedures
IF OBJECT_ID('ticket.sp_CreateBooking', 'P') IS NOT NULL DROP PROCEDURE ticket.sp_CreateBooking;
IF OBJECT_ID('ticket.sp_ValidateTicket', 'P') IS NOT NULL DROP PROCEDURE ticket.sp_ValidateTicket;
IF OBJECT_ID('ticket.sp_CancelBooking', 'P') IS NOT NULL DROP PROCEDURE ticket.sp_CancelBooking;
IF OBJECT_ID('ticket.sp_GenerateQRCode', 'P') IS NOT NULL DROP PROCEDURE ticket.sp_GenerateQRCode;
GO

-- Drop Triggers
IF OBJECT_ID('ticket.trg_UpdateEventSeats', 'TR') IS NOT NULL DROP TRIGGER ticket.trg_UpdateEventSeats;
IF OBJECT_ID('ticket.trg_LogTicketStatus', 'TR') IS NOT NULL DROP TRIGGER ticket.trg_LogTicketStatus;
GO

-- Drop Views
IF OBJECT_ID('ticket.vw_ActiveEvents', 'V') IS NOT NULL DROP VIEW ticket.vw_ActiveEvents;
IF OBJECT_ID('ticket.vw_UserBookings', 'V') IS NOT NULL DROP VIEW ticket.vw_UserBookings;
IF OBJECT_ID('ticket.vw_TicketDetails', 'V') IS NOT NULL DROP VIEW ticket.vw_TicketDetails;
IF OBJECT_ID('ticket.vw_DailySalesReport', 'V') IS NOT NULL DROP VIEW ticket.vw_DailySalesReport;
GO

-- Drop Tables (in correct order)
IF OBJECT_ID('ticket.TicketUsageLogs', 'U') IS NOT NULL DROP TABLE ticket.TicketUsageLogs;
IF OBJECT_ID('ticket.Tickets', 'U') IS NOT NULL DROP TABLE ticket.Tickets;
IF OBJECT_ID('ticket.Bookings', 'U') IS NOT NULL DROP TABLE ticket.Bookings;
IF OBJECT_ID('ticket.EventPricingTiers', 'U') IS NOT NULL DROP TABLE ticket.EventPricingTiers;
IF OBJECT_ID('ticket.Events', 'U') IS NOT NULL DROP TABLE ticket.Events;
IF OBJECT_ID('ticket.Venues', 'U') IS NOT NULL DROP TABLE ticket.Venues;
IF OBJECT_ID('ticket.EventCategories', 'U') IS NOT NULL DROP TABLE ticket.EventCategories;
IF OBJECT_ID('ticket.PaymentMethods', 'U') IS NOT NULL DROP TABLE ticket.PaymentMethods;
IF OBJECT_ID('ticket.Users', 'U') IS NOT NULL DROP TABLE ticket.Users;
GO

-- Drop Types
IF TYPE_ID('ticket.EventStatus') IS NOT NULL DROP TYPE ticket.EventStatus;
IF TYPE_ID('ticket.BookingStatus') IS NOT NULL DROP TYPE ticket.BookingStatus;
IF TYPE_ID('ticket.TicketStatus') IS NOT NULL DROP TYPE ticket.TicketStatus;
IF TYPE_ID('ticket.PaymentStatus') IS NOT NULL DROP TYPE ticket.PaymentStatus;
GO

-- ============================================================
-- 2. CREATE CUSTOM TYPES
-- ============================================================

CREATE TYPE ticket.EventStatus FROM VARCHAR(20);
CREATE TYPE ticket.BookingStatus FROM VARCHAR(20);
CREATE TYPE ticket.TicketStatus FROM VARCHAR(20);
CREATE TYPE ticket.PaymentStatus FROM VARCHAR(20);
GO

-- ============================================================
-- 3. CORE TABLES
-- ============================================================

-- Users/Customers Table
CREATE TABLE ticket.Users (
    UserID              BIGINT IDENTITY(1,1) PRIMARY KEY,
    Email               NVARCHAR(255) NOT NULL UNIQUE,
    PasswordHash        NVARCHAR(255) NOT NULL,
    FirstName           NVARCHAR(100) NOT NULL,
    LastName            NVARCHAR(100) NOT NULL,
    PhoneNumber         NVARCHAR(20) NULL,
    DateOfBirth         DATE NULL,
    Nationality         NVARCHAR(50) NULL,
    IDNumber            NVARCHAR(50) NULL, -- Passport/National ID
    IsVerified          BIT DEFAULT 0,
    IsActive            BIT DEFAULT 1,
    CreatedAt           DATETIME2 DEFAULT GETDATE(),
    UpdatedAt           DATETIME2 DEFAULT GETDATE(),
    LastLogin           DATETIME2 NULL,
    
    CONSTRAINT CHK_Email CHECK (Email LIKE '%_@__%.__%')
);
GO

CREATE INDEX IX_Users_Email ON ticket.Users(Email);
CREATE INDEX IX_Users_Phone ON ticket.Users(PhoneNumber);
GO

-- Payment Methods
CREATE TABLE ticket.PaymentMethods (
    PaymentMethodID     BIGINT IDENTITY(1,1) PRIMARY KEY,
    UserID              BIGINT NOT NULL,
    MethodType          NVARCHAR(50) NOT NULL CHECK (MethodType IN ('credit_card', 'debit_card', 'paypal', 'apple_pay', 'google_pay', 'bank_transfer', 'crypto')),
    Provider            NVARCHAR(50) NULL, -- Visa, Mastercard, etc.
    LastFourDigits      NVARCHAR(4) NULL,
    ExpiryMonth         TINYINT NULL CHECK (ExpiryMonth BETWEEN 1 AND 12),
    ExpiryYear          SMALLINT NULL,
    BillingAddress      NVARCHAR(MAX) NULL, -- JSON format
    IsDefault           BIT DEFAULT 0,
    IsActive            BIT DEFAULT 1,
    CreatedAt           DATETIME2 DEFAULT GETDATE(),
    
    CONSTRAINT FK_PaymentMethods_Users FOREIGN KEY (UserID) REFERENCES ticket.Users(UserID) ON DELETE CASCADE
);
GO

CREATE INDEX IX_PaymentMethods_UserID ON ticket.PaymentMethods(UserID, IsDefault);
GO

-- Event Categories
CREATE TABLE ticket.EventCategories (
    CategoryID          BIGINT IDENTITY(1,1) PRIMARY KEY,
    CategoryName        NVARCHAR(100) NOT NULL UNIQUE,
    Description         NVARCHAR(MAX) NULL,
    IconURL             NVARCHAR(500) NULL,
    ParentCategoryID    BIGINT NULL,
    IsActive            BIT DEFAULT 1,
    
    CONSTRAINT FK_Categories_Parent FOREIGN KEY (ParentCategoryID) REFERENCES ticket.EventCategories(CategoryID)
);
GO

CREATE INDEX IX_Categories_Name ON ticket.EventCategories(CategoryName);
GO

-- Venues (Stadiums, Theaters, Airports, Train Stations)
CREATE TABLE ticket.Venues (
    VenueID             BIGINT IDENTITY(1,1) PRIMARY KEY,
    VenueName           NVARCHAR(200) NOT NULL,
    VenueType           NVARCHAR(50) NOT NULL CHECK (VenueType IN ('stadium', 'theater', 'arena', 'conference_center', 'airport', 'train_station', 'bus_terminal', 'cinema', 'other')),
    AddressLine1        NVARCHAR(255) NOT NULL,
    AddressLine2        NVARCHAR(255) NULL,
    City                NVARCHAR(100) NOT NULL,
    StateProvince       NVARCHAR(100) NULL,
    PostalCode          NVARCHAR(20) NULL,
    Country             NVARCHAR(100) NOT NULL,
    Latitude            DECIMAL(10, 8) NULL,
    Longitude           DECIMAL(11, 8) NULL,
    Capacity            INT NULL,
    SeatingMapURL       NVARCHAR(500) NULL,
    Facilities          NVARCHAR(MAX) NULL, -- JSON: parking, accessibility, etc.
    ContactPhone        NVARCHAR(20) NULL,
    ContactEmail        NVARCHAR(255) NULL,
    IsActive            BIT DEFAULT 1,
    CreatedAt           DATETIME2 DEFAULT GETDATE()
);
GO

CREATE INDEX IX_Venues_Location ON ticket.Venues(City, Country);
CREATE INDEX IX_Venues_Type ON ticket.Venues(VenueType);
GO

-- Events (Concerts, Flights, Train Journeys, Movies)
CREATE TABLE ticket.Events (
    EventID             BIGINT IDENTITY(1,1) PRIMARY KEY,
    EventName           NVARCHAR(255) NOT NULL,
    EventType           NVARCHAR(50) NOT NULL CHECK (EventType IN ('concert', 'sports', 'theater', 'conference', 'flight', 'train', 'bus', 'movie', 'exhibition', 'other')),
    CategoryID          BIGINT NULL,
    VenueID             BIGINT NOT NULL,
    OrganizerID         BIGINT NULL,
    Description         NVARCHAR(MAX) NULL,
    ShortDescription    NVARCHAR(500) NULL,
    PosterImageURL      NVARCHAR(500) NULL,
    GalleryImages       NVARCHAR(MAX) NULL, -- JSON array
    
    -- Timing
    StartDateTime       DATETIME2 NOT NULL,
    EndDateTime         DATETIME2 NULL,
    DoorsOpenDateTime   DATETIME2 NULL,
    TimeZone            NVARCHAR(50) DEFAULT 'UTC',
    
    -- Status
    Status              NVARCHAR(20) DEFAULT 'draft' CHECK (Status IN ('draft', 'published', 'on_sale', 'sold_out', 'cancelled', 'postponed', 'completed')),
    IsFeatured          BIT DEFAULT 0,
    
    -- Capacity & Inventory
    TotalCapacity       INT NOT NULL,
    AvailableSeats      INT NOT NULL,
    ReservedSeats       INT DEFAULT 0,
    SoldSeats           INT DEFAULT 0,
    
    -- Additional Info
    AgeRestriction      NVARCHAR(20) NULL, -- 18+, All Ages, etc.
    TermsConditions     NVARCHAR(MAX) NULL,
    RefundPolicy        NVARCHAR(MAX) NULL,
    
    CreatedAt           DATETIME2 DEFAULT GETDATE(),
    UpdatedAt           DATETIME2 DEFAULT GETDATE(),
    
    CONSTRAINT FK_Events_Categories FOREIGN KEY (CategoryID) REFERENCES ticket.EventCategories(CategoryID),
    CONSTRAINT FK_Events_Venues FOREIGN KEY (VenueID) REFERENCES ticket.Venues(VenueID),
    CONSTRAINT CHK_Event_Dates CHECK (EndDateTime IS NULL OR EndDateTime > StartDateTime)
);
GO

CREATE INDEX IX_Events_Dates ON ticket.Events(StartDateTime, EndDateTime);
CREATE INDEX IX_Events_Status ON ticket.Events(Status);
CREATE INDEX IX_Events_Type ON ticket.Events(EventType);
CREATE FULLTEXT CATALOG ftCatalog AS DEFAULT;
CREATE FULLTEXT INDEX ON ticket.Events(EventName, Description) KEY INDEX PK__Events__7944C81012345678;
GO

-- Pricing Tiers (VIP, Standard, Economy, etc.)
CREATE TABLE ticket.EventPricingTiers (
    TierID              BIGINT IDENTITY(1,1) PRIMARY KEY,
    EventID             BIGINT NOT NULL,
    TierName            NVARCHAR(100) NOT NULL, -- "VIP", "General Admission"
    TierCode            NVARCHAR(20) NULL, -- Short code
    Description         NVARCHAR(MAX) NULL,
    
    -- Pricing
    BasePrice           DECIMAL(15, 2) NOT NULL,
    ServiceFeePercent   DECIMAL(5, 2) DEFAULT 0.00,
    ServiceFeeFixed     DECIMAL(10, 2) DEFAULT 0.00,
    TaxPercent          DECIMAL(5, 2) DEFAULT 0.00,
    
    -- Inventory
    TotalQuantity       INT NOT NULL,
    AvailableQuantity   INT NOT NULL,
    ReservedQuantity    INT DEFAULT 0,
    SoldQuantity        INT DEFAULT 0,
    
    -- Seating
    SeatingSection      NVARCHAR(100) NULL,
    SeatMapCoordinates  NVARCHAR(MAX) NULL, -- JSON for interactive seating
    
    -- Restrictions
    MaxPerCustomer      INT DEFAULT 10,
    MinPerCustomer      INT DEFAULT 1,
    
    -- Sales Window
    SaleStartDateTime   DATETIME2 NULL,
    SaleEndDateTime     DATETIME2 NULL,
    
    IsActive            BIT DEFAULT 1,
    CreatedAt           DATETIME2 DEFAULT GETDATE(),
    
    CONSTRAINT FK_Tiers_Events FOREIGN KEY (EventID) REFERENCES ticket.Events(EventID) ON DELETE CASCADE,
    CONSTRAINT CHK_Tier_Quantities CHECK (AvailableQuantity >= 0 AND ReservedQuantity >= 0 AND SoldQuantity >= 0)
);
GO

CREATE INDEX IX_Tiers_Event ON ticket.EventPricingTiers(EventID, IsActive);
CREATE INDEX IX_Tiers_Price ON ticket.EventPricingTiers(BasePrice);
GO

-- ============================================================
-- 4. BOOKING & TICKET TABLES
-- ============================================================

-- Bookings (Orders)
CREATE TABLE ticket.Bookings (
    BookingID           BIGINT IDENTITY(1,1) PRIMARY KEY,
    BookingReference    NVARCHAR(20) NOT NULL UNIQUE, -- Human-readable: "ETX-2024-001234"
    UserID              BIGINT NOT NULL,
    EventID             BIGINT NOT NULL,
    
    -- Status Workflow
    Status              NVARCHAR(20) DEFAULT 'pending' CHECK (Status IN ('pending', 'confirmed', 'payment_processing', 'paid', 'cancelled', 'refunded', 'partially_refunded', 'completed')),
    
    -- Financials
    SubtotalAmount      DECIMAL(15, 2) NOT NULL,
    ServiceFees         DECIMAL(15, 2) DEFAULT 0.00,
    TaxAmount           DECIMAL(15, 2) DEFAULT 0.00,
    DiscountAmount      DECIMAL(15, 2) DEFAULT 0.00,
    TotalAmount         DECIMAL(15, 2) NOT NULL,
    Currency            NVARCHAR(3) DEFAULT 'USD',
    
    -- Payment
    PaymentMethodID     BIGINT NULL,
    PaymentStatus       NVARCHAR(20) DEFAULT 'pending' CHECK (PaymentStatus IN ('pending', 'authorized', 'captured', 'failed', 'refunded')),
    PaymentTransactionID NVARCHAR(255) NULL,
    PaidAt              DATETIME2 NULL,
    
    -- Cancellation/Refund
    CancelledAt         DATETIME2 NULL,
    CancellationReason  NVARCHAR(MAX) NULL,
    RefundAmount        DECIMAL(15, 2) DEFAULT 0.00,
    RefundedAt          DATETIME2 NULL,
    
    -- Metadata
    IPAddress           NVARCHAR(45) NULL,
    UserAgent           NVARCHAR(MAX) NULL,
    Notes               NVARCHAR(MAX) NULL,
    
    CreatedAt           DATETIME2 DEFAULT GETDATE(),
    UpdatedAt           DATETIME2 DEFAULT GETDATE(),
    
    CONSTRAINT FK_Bookings_Users FOREIGN KEY (UserID) REFERENCES ticket.Users(UserID),
    CONSTRAINT FK_Bookings_Events FOREIGN KEY (EventID) REFERENCES ticket.Events(EventID),
    CONSTRAINT FK_Bookings_PaymentMethods FOREIGN KEY (PaymentMethodID) REFERENCES ticket.PaymentMethods(PaymentMethodID)
);
GO

CREATE INDEX IX_Bookings_Reference ON ticket.Bookings(BookingReference);
CREATE INDEX IX_Bookings_User ON ticket.Bookings(UserID, CreatedAt);
CREATE INDEX IX_Bookings_Status ON ticket.Bookings(Status);
CREATE INDEX IX_Bookings_Event ON ticket.Bookings(EventID);
GO

-- Individual Tickets
CREATE TABLE ticket.Tickets (
    TicketID            BIGINT IDENTITY(1,1) PRIMARY KEY,
    BookingID           BIGINT NOT NULL,
    TierID              BIGINT NOT NULL,
    
    -- Unique Ticket Identification
    TicketNumber        NVARCHAR(50) NOT NULL UNIQUE, -- "TKT-ABC123XYZ"
    QRCodeData          NVARCHAR(500) NOT NULL UNIQUE, -- Encrypted QR
    BarcodeData         NVARCHAR(500) NULL UNIQUE, -- Optional
    
    -- Attendee Info
    AttendeeName        NVARCHAR(200) NULL,
    AttendeeEmail       NVARCHAR(255) NULL,
    AttendeePhone       NVARCHAR(20) NULL,
    
    -- Seat/Assignment
    SeatRow             NVARCHAR(10) NULL,
    SeatNumber          NVARCHAR(10) NULL,
    SeatSection         NVARCHAR(50) NULL,
    GateEntrance        NVARCHAR(50) NULL,
    
    -- Pricing Breakdown
    BasePrice           DECIMAL(15, 2) NOT NULL,
    ServiceFee          DECIMAL(10, 2) DEFAULT 0.00,
    TaxAmount           DECIMAL(10, 2) DEFAULT 0.00,
    TotalPrice          DECIMAL(15, 2) NOT NULL,
    
    -- Status
    Status              NVARCHAR(20) DEFAULT 'reserved' CHECK (Status IN ('reserved', 'issued', 'sent', 'validated', 'used', 'expired', 'cancelled', 'refunded')),
    
    -- Dates
    IssuedAt            DATETIME2 NULL,
    SentAt              DATETIME2 NULL,
    ValidFrom           DATETIME2 NULL,
    ValidUntil          DATETIME2 NULL,
    
    -- Usage
    UsedAt              DATETIME2 NULL,
    UsedBy              NVARCHAR(100) NULL, -- Scanner/Staff ID
    EntryGate           NVARCHAR(50) NULL,
    
    -- Transferability
    IsTransferable      BIT DEFAULT 1,
    TransferredFrom     BIGINT NULL, -- Previous TicketID
    TransferredAt       DATETIME2 NULL,
    
    -- Security
    CheckInCount        INT DEFAULT 0,
    MaxCheckIns         INT DEFAULT 1,
    
    CreatedAt           DATETIME2 DEFAULT GETDATE(),
    UpdatedAt           DATETIME2 DEFAULT GETDATE(),
    
    CONSTRAINT FK_Tickets_Bookings FOREIGN KEY (BookingID) REFERENCES ticket.Bookings(BookingID) ON DELETE CASCADE,
    CONSTRAINT FK_Tickets_Tiers FOREIGN KEY (TierID) REFERENCES ticket.EventPricingTiers(TierID),
    CONSTRAINT FK_Tickets_Transferred FOREIGN KEY (TransferredFrom) REFERENCES ticket.Tickets(TicketID)
);
GO

CREATE INDEX IX_Tickets_Number ON ticket.Tickets(TicketNumber);
CREATE INDEX IX_Tickets_QRCode ON ticket.Tickets(QRCodeData);
CREATE INDEX IX_Tickets_Status ON ticket.Tickets(Status);
CREATE INDEX IX_Tickets_Booking ON ticket.Tickets(BookingID);
CREATE INDEX IX_Tickets_ValidDates ON ticket.Tickets(ValidFrom, ValidUntil);
GO

-- Ticket Usage/Scan Logs (Audit Trail)
CREATE TABLE ticket.TicketUsageLogs (
    LogID               BIGINT IDENTITY(1,1) PRIMARY KEY,
    TicketID            BIGINT NOT NULL,
    Action              NVARCHAR(50) NOT NULL CHECK (Action IN ('viewed', 'sent', 'downloaded', 'validated', 'scanned', 'entry_granted', 'entry_denied', 'transferred', 'refunded')),
    
    -- Scanner Info
    DeviceID            NVARCHAR(100) NULL,
    ScannerID           NVARCHAR(100) NULL,
    Location            NVARCHAR(100) NULL,
    IPAddress           NVARCHAR(45) NULL,
    
    -- Result
    Success             BIT DEFAULT 1,
    FailureReason       NVARCHAR(255) NULL,
    
    -- Geo
    Latitude            DECIMAL(10, 8) NULL,
    Longitude           DECIMAL(11, 8) NULL,
    UserAgent           NVARCHAR(MAX) NULL,
    Notes               NVARCHAR(MAX) NULL,
    
    CreatedAt           DATETIME2 DEFAULT GETDATE(),
    
    CONSTRAINT FK_Logs_Tickets FOREIGN KEY (TicketID) REFERENCES ticket.Tickets(TicketID) ON DELETE CASCADE
);
GO

CREATE INDEX IX_Logs_Ticket ON ticket.TicketUsageLogs(TicketID, CreatedAt);
CREATE INDEX IX_Logs_Action ON ticket.TicketUsageLogs(Action);
CREATE INDEX IX_Logs_Time ON ticket.TicketUsageLogs(CreatedAt);
GO

-- ============================================================
-- 5. VIEWS
-- ============================================================

-- View: Active Events with Availability
CREATE VIEW ticket.vw_ActiveEvents
AS
SELECT 
    e.EventID,
    e.EventName,
    e.EventType,
    e.StartDateTime,
    e.EndDateTime,
    v.VenueName,
    v.City,
    e.TotalCapacity,
    e.AvailableSeats,
    e.Status,
    MIN(pt.BasePrice) AS MinPrice,
    MAX(pt.BasePrice) AS MaxPrice
FROM ticket.Events e
JOIN ticket.Venues v ON e.VenueID = v.VenueID
LEFT JOIN ticket.EventPricingTiers pt ON e.EventID = pt.EventID AND pt.IsActive = 1
WHERE e.Status IN ('published', 'on_sale')
GROUP BY e.EventID, e.EventName, e.EventType, e.StartDateTime, e.EndDateTime, 
         v.VenueName, v.City, e.TotalCapacity, e.AvailableSeats, e.Status;
GO

-- View: User Bookings Summary
CREATE VIEW ticket.vw_UserBookings
AS
SELECT 
    b.BookingID,
    b.BookingReference,
    b.UserID,
    u.Email,
    e.EventName,
    e.StartDateTime,
    b.Status AS BookingStatus,
    b.TotalAmount,
    b.Currency,
    COUNT(t.TicketID) AS TicketCount,
    b.CreatedAt
FROM ticket.Bookings b
JOIN ticket.Users u ON b.UserID = u.UserID
JOIN ticket.Events e ON b.EventID = e.EventID
LEFT JOIN ticket.Tickets t ON b.BookingID = t.BookingID
GROUP BY b.BookingID, b.BookingReference, b.UserID, u.Email, e.EventName, 
         e.StartDateTime, b.Status, b.TotalAmount, b.Currency, b.CreatedAt;
GO

-- View: Ticket Details with Event Info
CREATE VIEW ticket.vw_TicketDetails
AS
SELECT 
    t.TicketID,
    t.TicketNumber,
    t.QRCodeData,
    t.Status AS TicketStatus,
    t.AttendeeName,
    t.SeatRow,
    t.SeatNumber,
    t.ValidUntil,
    b.BookingReference,
    e.EventName,
    e.StartDateTime,
    v.VenueName,
    v.AddressLine1,
    v.City,
    pt.TierName,
    t.TotalPrice
FROM ticket.Tickets t
JOIN ticket.Bookings b ON t.BookingID = b.BookingID
JOIN ticket.EventPricingTiers pt ON t.TierID = pt.TierID
JOIN ticket.Events e ON b.EventID = e.EventID
JOIN ticket.Venues v ON e.VenueID = v.VenueID;
GO

-- View: Daily Sales Report
CREATE VIEW ticket.vw_DailySalesReport
AS
SELECT 
    CAST(b.CreatedAt AS DATE) AS SaleDate,
    e.EventName,
    COUNT(DISTINCT b.BookingID) AS TotalBookings,
    SUM(b.TotalAmount) AS TotalRevenue,
    COUNT(t.TicketID) AS TicketsSold,
    AVG(b.TotalAmount) AS AverageOrderValue
FROM ticket.Bookings b
JOIN ticket.Events e ON b.EventID = e.EventID
LEFT JOIN ticket.Tickets t ON b.BookingID = t.BookingID
WHERE b.Status IN ('paid', 'completed')
GROUP BY CAST(b.CreatedAt AS DATE), e.EventName;
GO

-- ============================================================
-- 6. STORED PROCEDURES
-- ============================================================

-- Procedure: Generate Unique Booking Reference
CREATE PROCEDURE ticket.sp_GenerateBookingReference
    @BookingReference NVARCHAR(20) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @Year NVARCHAR(4) = CAST(YEAR(GETDATE()) AS NVARCHAR(4));
    DECLARE @Random NVARCHAR(6);
    DECLARE @Exists INT = 1;
    
    WHILE @Exists = 1
    BEGIN
        SET @Random = RIGHT('000000' + CAST(CAST(RAND() * 1000000 AS INT) AS NVARCHAR(6)), 6);
        SET @BookingReference = 'ETX-' + @Year + '-' + @Random;
        
        SELECT @Exists = COUNT(*) FROM ticket.Bookings WHERE BookingReference = @BookingReference;
    END
END
GO

-- Procedure: Create New Booking with Tickets
CREATE PROCEDURE ticket.sp_CreateBooking
    @UserID BIGINT,
    @EventID BIGINT,
    @TierID BIGINT,
    @Quantity INT,
    @PaymentMethodID BIGINT,
    @BookingID BIGINT OUTPUT,
    @BookingReference NVARCHAR(20) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    
    BEGIN TRANSACTION;
    BEGIN TRY
        DECLARE @Available INT;
        DECLARE @BasePrice DECIMAL(15,2);
        DECLARE @ServiceFee DECIMAL(10,2);
        DECLARE @TaxRate DECIMAL(5,2);
        DECLARE @Subtotal DECIMAL(15,2);
        DECLARE @Total DECIMAL(15,2);
        DECLARE @Counter INT = 0;
        DECLARE @TicketNumber NVARCHAR(50);
        DECLARE @QRCode NVARCHAR(500);
        DECLARE @ValidUntil DATETIME2;
        
        -- Lock the tier row
        SELECT @Available = AvailableQuantity, 
               @BasePrice = BasePrice, 
               @ServiceFee = ServiceFeeFixed, 
               @TaxRate = TaxPercent
        FROM ticket.EventPricingTiers WITH (UPDLOCK, HOLDLOCK)
        WHERE TierID = @TierID;
        
        -- Check availability
        IF @Available < @Quantity
        BEGIN
            RAISERROR('Insufficient tickets available', 16, 1);
            RETURN;
        END
        
        -- Get event end date for ticket validity
        SELECT @ValidUntil = EndDateTime FROM ticket.Events WHERE EventID = @EventID;
        
        -- Calculate totals
        SET @Subtotal = @BasePrice * @Quantity;
        SET @Total = @Subtotal + (@ServiceFee * @Quantity) + (@Subtotal * @TaxRate / 100);
        
        -- Generate booking reference
        EXEC ticket.sp_GenerateBookingReference @BookingReference OUTPUT;
        
        -- Create booking
        INSERT INTO ticket.Bookings (
            BookingReference, UserID, EventID, Status,
            SubtotalAmount, ServiceFees, TaxAmount, TotalAmount,
            PaymentMethodID
        ) VALUES (
            @BookingReference, @UserID, @EventID, 'pending',
            @Subtotal, @ServiceFee * @Quantity, @Subtotal * @TaxRate / 100, @Total,
            @PaymentMethodID
        );
        
        SET @BookingID = SCOPE_IDENTITY();
        
        -- Update tier availability
        UPDATE ticket.EventPricingTiers 
        SET AvailableQuantity = AvailableQuantity - @Quantity,
            ReservedQuantity = ReservedQuantity + @Quantity
        WHERE TierID = @TierID;
        
        -- Create tickets
        WHILE @Counter < @Quantity
        BEGIN
            SET @TicketNumber = 'TKT-' + UPPER(SUBSTRING(CONVERT(NVARCHAR(50), NEWID()), 1, 10));
            SET @QRCode = 'ETX:' + CAST(@BookingID AS NVARCHAR) + ':' + 
                         CAST(DATEDIFF(SECOND, '1970-01-01', GETUTCDATE()) AS NVARCHAR) + ':' +
                         UPPER(SUBSTRING(CONVERT(NVARCHAR(50), NEWID()), 1, 16));
            
            INSERT INTO ticket.Tickets (
                BookingID, TierID, TicketNumber, QRCodeData,
                BasePrice, ServiceFee, TaxAmount, TotalPrice,
                Status, ValidFrom, ValidUntil
            ) VALUES (
                @BookingID, @TierID, @TicketNumber, @QRCode,
                @BasePrice, @ServiceFee, @BasePrice * @TaxRate / 100, 
                @BasePrice + @ServiceFee + (@BasePrice * @TaxRate / 100),
                'reserved',
                GETDATE(),
                @ValidUntil
            );
            
            SET @Counter = @Counter + 1;
        END
        
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO

-- Procedure: Validate and Use Ticket
CREATE PROCEDURE ticket.sp_ValidateTicket
    @QRCode NVARCHAR(500),
    @ScannerID NVARCHAR(100),
    @DeviceID NVARCHAR(100),
    @Location NVARCHAR(100),
    @Result NVARCHAR(255) OUTPUT,
    @TicketID BIGINT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @Status NVARCHAR(20);
    DECLARE @ValidUntil DATETIME2;
    DECLARE @MaxCheckIns INT;
    DECLARE @CheckInCount INT;
    DECLARE @EventEnd DATETIME2;
    
    SELECT 
        @TicketID = t.TicketID, 
        @Status = t.Status, 
        @ValidUntil = t.ValidUntil, 
        @MaxCheckIns = t.MaxCheckIns, 
        @CheckInCount = t.CheckInCount, 
        @EventEnd = e.EndDateTime
    FROM ticket.Tickets t
    JOIN ticket.Bookings b ON t.BookingID = b.BookingID
    JOIN ticket.Events e ON b.EventID = e.EventID
    WHERE t.QRCodeData = @QRCode;
    
    IF @TicketID IS NULL
    BEGIN
        SET @Result = 'INVALID: Ticket not found';
        INSERT INTO ticket.TicketUsageLogs (TicketID, Action, ScannerID, DeviceID, Location, Success, FailureReason)
        VALUES (NULL, 'validated', @ScannerID, @DeviceID, @Location, 0, 'Ticket not found');
        RETURN;
    END
    
    IF @Status = 'used' AND @CheckInCount >= @MaxCheckIns
    BEGIN
        SET @Result = 'INVALID: Ticket already used';
        INSERT INTO ticket.TicketUsageLogs (TicketID, Action, ScannerID, DeviceID, Location, Success, FailureReason)
        VALUES (@TicketID, 'entry_denied', @ScannerID, @DeviceID, @Location, 0, 'Already used');
        RETURN;
    END
    
    IF @Status = 'cancelled'
    BEGIN
        SET @Result = 'INVALID: Ticket cancelled';
        INSERT INTO ticket.TicketUsageLogs (TicketID, Action, ScannerID, DeviceID, Location, Success, FailureReason)
        VALUES (@TicketID, 'entry_denied', @ScannerID, @DeviceID, @Location, 0, 'Cancelled');
        RETURN;
    END
    
    IF @Status = 'expired' OR @ValidUntil < GETDATE() OR @EventEnd < GETDATE()
    BEGIN
        SET @Result = 'INVALID: Ticket expired';
        INSERT INTO ticket.TicketUsageLogs (TicketID, Action, ScannerID, DeviceID, Location, Success, FailureReason)
        VALUES (@TicketID, 'entry_denied', @ScannerID, @DeviceID, @Location, 0, 'Expired');
        RETURN;
    END
    
    -- Valid ticket
    SET @Result = 'VALID: Entry granted';
    
    UPDATE ticket.Tickets 
    SET Status = 'used', 
        UsedAt = GETDATE(),
        CheckInCount = CheckInCount + 1,
        UsedBy = @ScannerID
    WHERE TicketID = @TicketID;
    
    INSERT INTO ticket.TicketUsageLogs (TicketID, Action, ScannerID, DeviceID, Location, Success)
    VALUES (@TicketID, 'entry_granted', @ScannerID, @DeviceID, @Location, 1);
END
GO

-- Procedure: Cancel Booking
CREATE PROCEDURE ticket.sp_CancelBooking
    @BookingID BIGINT,
    @Reason NVARCHAR(MAX),
    @Success BIT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    
    BEGIN TRANSACTION;
    BEGIN TRY
        DECLARE @Status NVARCHAR(20);
        DECLARE @EventDate DATETIME2;
        
        SELECT @Status = b.Status, @EventDate = e.StartDateTime
        FROM ticket.Bookings b
        JOIN ticket.Events e ON b.EventID = e.EventID
        WHERE b.BookingID = @BookingID;
        
        IF @EventDate <= GETDATE()
        BEGIN
            SET @Success = 0;
            RAISERROR('Cannot cancel: Event already started or passed', 16, 1);
            RETURN;
        END
        
        IF @Status IN ('cancelled', 'refunded')
        BEGIN
            SET @Success = 0;
            RAISERROR('Booking already cancelled', 16, 1);
            RETURN;
        END
        
        -- Update booking
        UPDATE ticket.Bookings 
        SET Status = 'cancelled', 
            CancelledAt = GETDATE(),
            CancellationReason = @Reason
        WHERE BookingID = @BookingID;
        
        -- Update tickets
        UPDATE ticket.Tickets 
        SET Status = 'cancelled' 
        WHERE BookingID = @BookingID AND Status NOT IN ('used', 'cancelled');
        
        -- Return inventory
        UPDATE pt
        SET pt.AvailableQuantity = pt.AvailableQuantity + 1,
            pt.ReservedQuantity = pt.ReservedQuantity - 1
        FROM ticket.EventPricingTiers pt
        JOIN ticket.Tickets t ON pt.TierID = t.TierID
        WHERE t.BookingID = @BookingID AND t.Status = 'cancelled';
        
        SET @Success = 1;
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        SET @Success = 0;
        THROW;
    END CATCH
END
GO

-- Procedure: Get Event Statistics
CREATE PROCEDURE ticket.sp_GetEventStatistics
    @EventID BIGINT
AS
BEGIN
    SET NOCOUNT ON;
    
    SELECT 
        e.EventName,
        e.TotalCapacity,
        e.AvailableSeats,
        e.SoldSeats,
        CAST(CAST(e.SoldSeats AS FLOAT) / CAST(e.TotalCapacity AS FLOAT) * 100 AS DECIMAL(5,2)) AS SoldPercentage,
        COUNT(DISTINCT b.BookingID) AS TotalBookings,
        SUM(b.TotalAmount) AS TotalRevenue,
        AVG(b.TotalAmount) AS AverageBookingValue
    FROM ticket.Events e
    LEFT JOIN ticket.Bookings b ON e.EventID = b.EventID AND b.Status IN ('paid', 'completed')
    WHERE e.EventID = @EventID
    GROUP BY e.EventName, e.TotalCapacity, e.AvailableSeats, e.SoldSeats;
END
GO

-- ============================================================
-- 7. TRIGGERS
-- ============================================================

-- Trigger: Update event available seats when tier changes
CREATE TRIGGER ticket.trg_UpdateEventSeats
ON ticket.EventPricingTiers
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    
    IF UPDATE(AvailableQuantity)
    BEGIN
        UPDATE e
        SET e.AvailableSeats = (
            SELECT COALESCE(SUM(AvailableQuantity), 0) 
            FROM ticket.EventPricingTiers 
            WHERE EventID = e.EventID AND IsActive = 1
        ),
        e.UpdatedAt = GETDATE()
        FROM ticket.Events e
        INNER JOIN inserted i ON e.EventID = i.EventID;
    END
END
GO

-- Trigger: Log ticket status changes
CREATE TRIGGER ticket.trg_LogTicketStatus
ON ticket.Tickets
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    
    IF UPDATE(Status)
    BEGIN
        INSERT INTO ticket.TicketUsageLogs (TicketID, Action, Success, Notes)
        SELECT 
            i.TicketID,
            CASE i.Status
                WHEN 'issued' THEN 'sent'
                WHEN 'used' THEN 'scanned'
                WHEN 'cancelled' THEN 'refunded'
                ELSE 'viewed'
            END,
            1,
            'Status changed from ' + d.Status + ' to ' + i.Status
        FROM inserted i
        INNER JOIN deleted d ON i.TicketID = d.TicketID
        WHERE i.Status != d.Status;
    END
END
GO

-- Trigger: Update UpdatedAt timestamp
CREATE TRIGGER ticket.trg_UpdateUsersTimestamp
ON ticket.Users
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE ticket.Users SET UpdatedAt = GETDATE() WHERE UserID IN (SELECT UserID FROM inserted);
END
GO

-- ============================================================
-- 8. FUNCTIONS
-- ============================================================

-- Function: Calculate Ticket Price with Fees
CREATE FUNCTION ticket.fn_CalculateTicketPrice
(
    @BasePrice DECIMAL(15,2),
    @ServiceFeeFixed DECIMAL(10,2),
    @ServiceFeePercent DECIMAL(5,2),
    @TaxPercent DECIMAL(5,2),
    @Quantity INT
)
RETURNS DECIMAL(15,2)
AS
BEGIN
    DECLARE @Subtotal DECIMAL(15,2) = @BasePrice * @Quantity;
    DECLARE @ServiceFee DECIMAL(15,2) = (@ServiceFeeFixed * @Quantity) + (@Subtotal * @ServiceFeePercent / 100);
    DECLARE @Tax DECIMAL(15,2) = @Subtotal * @TaxPercent / 100;
    
    RETURN @Subtotal + @ServiceFee + @Tax;
END
GO

-- Function: Check Ticket Validity
CREATE FUNCTION ticket.fn_IsTicketValid
(
    @TicketID BIGINT
)
RETURNS BIT
AS
BEGIN
    DECLARE @IsValid BIT = 0;
    DECLARE @Status NVARCHAR(20);
    DECLARE @ValidUntil DATETIME2;
    DECLARE @EventEnd DATETIME2;
    
    SELECT 
        @Status = t.Status,
        @ValidUntil = t.ValidUntil,
        @EventEnd = e.EndDateTime
    FROM ticket.Tickets t
    JOIN ticket.Bookings b ON t.BookingID = b.BookingID
    JOIN ticket.Events e ON b.EventID = e.EventID
    WHERE t.TicketID = @TicketID;
    
    IF @Status IN ('issued', 'sent', 'validated') 
       AND @ValidUntil > GETDATE() 
       AND @EventEnd > GETDATE()
    BEGIN
        SET @IsValid = 1;
    END
    
    RETURN @IsValid;
END
GO

-- Function: Get User Ticket History
CREATE FUNCTION ticket.fn_GetUserTicketHistory
(
    @UserID BIGINT
)
RETURNS TABLE
AS
RETURN
(
    SELECT 
        t.TicketID,
        t.TicketNumber,
        e.EventName,
        e.StartDateTime,
        t.Status,
        t.TotalPrice,
        t.CreatedAt
    FROM ticket.Tickets t
    JOIN ticket.Bookings b ON t.BookingID = b.BookingID
    JOIN ticket.Events e ON b.EventID = e.EventID
    WHERE b.UserID = @UserID
);
GO

-- ============================================================
-- 9. SAMPLE DATA
-- ============================================================

-- Sample Categories
INSERT INTO ticket.EventCategories (CategoryName, Description) VALUES
('Music', 'Concerts, festivals, and musical performances'),
('Sports', 'Sporting events and competitions'),
('Theater', 'Plays, musicals, and theatrical performances'),
('Cinema', 'Movies and film screenings'),
('Transport', 'Flights, trains, and bus tickets'),
('Conference', 'Business and educational conferences');
GO

-- Sample Venues
INSERT INTO ticket.Venues (VenueName, VenueType, AddressLine1, City, Country, Capacity, Latitude, Longitude) VALUES
('Madison Square Garden', 'arena', '4 Pennsylvania Plaza', 'New York', 'USA', 20789, 40.7505, -73.9934),
('O2 Arena', 'arena', 'Peninsula Square', 'London', 'UK', 20000, 51.5030, 0.0032),
('Heathrow Airport T5', 'airport', 'Heathrow Airport', 'London', 'UK', 5000, 51.4700, -0.4543),
('Tokyo Dome', 'stadium', '1-3-61 Koraku', 'Tokyo', 'Japan', 55000, 35.7056, 139.7530);
GO

-- Sample Events
INSERT INTO ticket.Events (EventName, EventType, CategoryID, VenueID, Description, StartDateTime, EndDateTime, TotalCapacity, AvailableSeats, Status) VALUES
('Rock Festival 2024', 'concert', 1, 1, 'Annual rock music festival featuring top artists', '2024-07-15 18:00:00', '2024-07-15 23:00:00', 15000, 15000, 'on_sale'),
('NBA Finals Game 1', 'sports', 2, 1, 'Championship basketball game', '2024-06-01 20:00:00', '2024-06-01 23:00:00', 20789, 5000, 'on_sale'),
('Tokyo Jazz Night', 'concert', 1, 4, 'International jazz performance', '2024-08-20 19:00:00', '2024-08-20 22:00:00', 55000, 30000, 'on_sale');
GO

-- Sample Pricing Tiers
INSERT INTO ticket.EventPricingTiers (EventID, TierName, TierCode, BasePrice, ServiceFeeFixed, TotalQuantity, AvailableQuantity, MaxPerCustomer) VALUES
(1, 'General Admission', 'GA', 89.99, 5.00, 10000, 10000, 6),
(1, 'VIP Package', 'VIP', 249.99, 10.00, 500, 500, 2),
(1, 'Backstage Pass', 'BACK', 499.99, 15.00, 100, 100, 1),
(2, 'Upper Level', 'UPPER', 150.00, 8.00, 10000, 5000, 4),
(2, 'Courtside', 'COURT', 1200.00, 25.00, 200, 50, 2),
(3, 'Standard', 'STD', 75.00, 3.00, 40000, 30000, 8),
(3, 'Premium Seat', 'PRM', 150.00, 5.00, 15000, 0, 4); -- Sold out
GO

-- Sample Users
INSERT INTO ticket.Users (Email, PasswordHash, FirstName, LastName, PhoneNumber, IsVerified) VALUES
('john.doe@email.com', 'HASH_VALUE_1', 'John', 'Doe', '+1-555-0101', 1),
('jane.smith@email.com', 'HASH_VALUE_2', 'Jane', 'Smith', '+1-555-0102', 1),
('bob.wilson@email.com', 'HASH_VALUE_3', 'Bob', 'Wilson', '+1-555-0103', 0);
GO

PRINT 'E-Ticket Database for SQL Server created successfully!';
PRINT 'Schema: ticket';
PRINT 'Tables: Users, PaymentMethods, EventCategories, Venues, Events, EventPricingTiers, Bookings, Tickets, TicketUsageLogs';
PRINT 'Views: vw_ActiveEvents, vw_UserBookings, vw_TicketDetails, vw_DailySalesReport';
PRINT 'Procedures: sp_CreateBooking, sp_ValidateTicket, sp_CancelBooking, sp_GetEventStatistics';
PRINT 'Functions: fn_CalculateTicketPrice, fn_IsTicketValid, fn_GetUserTicketHistory';
GO


