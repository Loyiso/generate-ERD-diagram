-- =============================================================================
-- ProductOrder Database
-- Azure SQL / SQL Server 2019+
-- =============================================================================

-- Run this script once against your Azure SQL server.
-- The database must already exist (create it in the Azure Portal first),
-- then connect to it and run everything below.

-- =============================================================================
-- CUSTOMERS
-- =============================================================================
CREATE TABLE dbo.Customers (
    Id        UNIQUEIDENTIFIER  NOT NULL  DEFAULT NEWSEQUENTIALID(),
    FirstName NVARCHAR(100)     NOT NULL,
    LastName  NVARCHAR(100)     NOT NULL,
    Email     NVARCHAR(256)     NOT NULL,
    CreatedAt DATETIME2(7)      NOT NULL  DEFAULT SYSUTCDATETIME(),

    CONSTRAINT PK_Customers PRIMARY KEY (Id),
    CONSTRAINT UQ_Customers_Email UNIQUE (Email)
);
GO

-- =============================================================================
-- PRODUCTS
-- =============================================================================
CREATE TABLE dbo.Products (
    Id            UNIQUEIDENTIFIER  NOT NULL  DEFAULT NEWSEQUENTIALID(),
    Name          NVARCHAR(200)     NOT NULL,
    Description   NVARCHAR(1000)    NULL,
    Price         DECIMAL(18, 2)    NOT NULL,
    Currency      NCHAR(3)          NOT NULL  DEFAULT 'USD',
    StockQuantity INT               NOT NULL  DEFAULT 0,
    IsActive      BIT               NOT NULL  DEFAULT 1,
    CreatedAt     DATETIME2(7)      NOT NULL  DEFAULT SYSUTCDATETIME(),

    CONSTRAINT PK_Products          PRIMARY KEY (Id),
    CONSTRAINT CK_Products_Price    CHECK (Price >= 0),
    CONSTRAINT CK_Products_Stock    CHECK (StockQuantity >= 0),
    CONSTRAINT CK_Products_Currency CHECK (LEN(RTRIM(Currency)) = 3)
);
GO

-- =============================================================================
-- ORDERS
-- =============================================================================
CREATE TABLE dbo.Orders (
    Id         UNIQUEIDENTIFIER  NOT NULL  DEFAULT NEWSEQUENTIALID(),
    CustomerId UNIQUEIDENTIFIER  NOT NULL,
    Status     NVARCHAR(20)      NOT NULL  DEFAULT 'Draft',
    PlacedAt   DATETIME2(7)      NOT NULL  DEFAULT SYSUTCDATETIME(),

    CONSTRAINT PK_Orders            PRIMARY KEY (Id),
    CONSTRAINT FK_Orders_Customers  FOREIGN KEY (CustomerId)
        REFERENCES dbo.Customers (Id),
    CONSTRAINT CK_Orders_Status     CHECK (Status IN (
        'Draft', 'Placed', 'Processing', 'Shipped', 'Delivered', 'Cancelled'
    ))
);
GO

-- =============================================================================
-- ORDER ITEMS
-- =============================================================================
CREATE TABLE dbo.OrderItems (
    Id        UNIQUEIDENTIFIER  NOT NULL  DEFAULT NEWSEQUENTIALID(),
    OrderId   UNIQUEIDENTIFIER  NOT NULL,
    ProductId UNIQUEIDENTIFIER  NOT NULL,
    UnitPrice DECIMAL(18, 2)    NOT NULL,
    Currency  NCHAR(3)          NOT NULL  DEFAULT 'USD',
    Quantity  INT               NOT NULL,

    CONSTRAINT PK_OrderItems            PRIMARY KEY (Id),
    CONSTRAINT FK_OrderItems_Orders     FOREIGN KEY (OrderId)
        REFERENCES dbo.Orders (Id)  ON DELETE CASCADE,
    CONSTRAINT FK_OrderItems_Products   FOREIGN KEY (ProductId)
        REFERENCES dbo.Products (Id),
    CONSTRAINT CK_OrderItems_Quantity   CHECK (Quantity > 0),
    CONSTRAINT CK_OrderItems_UnitPrice  CHECK (UnitPrice >= 0)
);
GO

-- =============================================================================
-- INDEXES
-- =============================================================================

-- Look up orders by customer
CREATE NONCLUSTERED INDEX IX_Orders_CustomerId
    ON dbo.Orders (CustomerId)
    INCLUDE (Status, PlacedAt);
GO

-- Look up items by order (covered for common order detail queries)
CREATE NONCLUSTERED INDEX IX_OrderItems_OrderId
    ON dbo.OrderItems (OrderId)
    INCLUDE (ProductId, UnitPrice, Currency, Quantity);
GO

-- Look up items by product (e.g. "has this product been ordered?")
CREATE NONCLUSTERED INDEX IX_OrderItems_ProductId
    ON dbo.OrderItems (ProductId);
GO

-- Active product listing
CREATE NONCLUSTERED INDEX IX_Products_IsActive_Name
    ON dbo.Products (IsActive, Name)
    INCLUDE (Price, Currency, StockQuantity);
GO

-- =============================================================================
-- SEED DATA (optional — remove for production)
-- =============================================================================

INSERT INTO dbo.Customers (Id, FirstName, LastName, Email, CreatedAt)
VALUES
    ('A0000001-0000-0000-0000-000000000001', 'Alice',   'Nkosi',   'alice.nkosi@example.com',   SYSUTCDATETIME()),
    ('A0000001-0000-0000-0000-000000000002', 'Brian',   'Dlamini', 'brian.dlamini@example.com', SYSUTCDATETIME()),
    ('A0000001-0000-0000-0000-000000000003', 'Carla',   'Mokoena', 'carla.mokoena@example.com', SYSUTCDATETIME());
GO

INSERT INTO dbo.Products (Id, Name, Description, Price, Currency, StockQuantity, IsActive)
VALUES
    ('B0000001-0000-0000-0000-000000000001', 'Wireless Keyboard', 'Compact mechanical keyboard',  899.99, 'ZAR', 50,  1),
    ('B0000001-0000-0000-0000-000000000002', 'USB-C Hub',         '7-in-1 USB-C docking station', 599.00, 'ZAR', 120, 1),
    ('B0000001-0000-0000-0000-000000000003', 'Monitor Stand',     'Adjustable aluminium stand',   349.50, 'ZAR', 30,  1),
    ('B0000001-0000-0000-0000-000000000004', 'Webcam HD',         '1080p USB webcam',             449.00, 'ZAR', 75,  1);
GO

INSERT INTO dbo.Orders (Id, CustomerId, Status, PlacedAt)
VALUES
    ('C0000001-0000-0000-0000-000000000001', 'A0000001-0000-0000-0000-000000000001', 'Placed',    SYSUTCDATETIME()),
    ('C0000001-0000-0000-0000-000000000002', 'A0000001-0000-0000-0000-000000000002', 'Delivered', SYSUTCDATETIME()),
    ('C0000001-0000-0000-0000-000000000003', 'A0000001-0000-0000-0000-000000000001', 'Cancelled', SYSUTCDATETIME());
GO

INSERT INTO dbo.OrderItems (Id, OrderId, ProductId, UnitPrice, Currency, Quantity)
VALUES
    ('D0000001-0000-0000-0000-000000000001', 'C0000001-0000-0000-0000-000000000001', 'B0000001-0000-0000-0000-000000000001', 899.99, 'ZAR', 1),
    ('D0000001-0000-0000-0000-000000000002', 'C0000001-0000-0000-0000-000000000001', 'B0000001-0000-0000-0000-000000000002', 599.00, 'ZAR', 2),
    ('D0000001-0000-0000-0000-000000000003', 'C0000001-0000-0000-0000-000000000002', 'B0000001-0000-0000-0000-000000000003', 349.50, 'ZAR', 1),
    ('D0000001-0000-0000-0000-000000000004', 'C0000001-0000-0000-0000-000000000002', 'B0000001-0000-0000-0000-000000000004', 449.00, 'ZAR', 3),
    ('D0000001-0000-0000-0000-000000000005', 'C0000001-0000-0000-0000-000000000003', 'B0000001-0000-0000-0000-000000000001', 899.99, 'ZAR', 1);
GO
