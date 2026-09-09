CREATE DATABASE IF NOT EXISTS cc;
USE cc;

DROP TABLE IF EXISTS Loans;
DROP TABLE IF EXISTS BookCopies;
DROP TABLE IF EXISTS Members;
DROP TABLE IF EXISTS Librarians;
DROP TABLE IF EXISTS Books;

CREATE TABLE Books (
    ISBN VARCHAR(20) NOT NULL,
    Title VARCHAR(255) NOT NULL,
    Author VARCHAR(255) NOT NULL,
    Publisher VARCHAR(150),
    PubYear SMALLINT,
    Category VARCHAR(100),
    CONSTRAINT pk_books PRIMARY KEY (ISBN)
);

CREATE TABLE BookCopies (
    CopyID INT NOT NULL AUTO_INCREMENT,
    ISBN VARCHAR(20) NOT NULL,
    ShelfLocation VARCHAR(50),
    Status VARCHAR(20) NOT NULL DEFAULT 'Available',
    CONSTRAINT pk_bookcopies PRIMARY KEY (CopyID),
    CONSTRAINT fk_bookcopies_book FOREIGN KEY (ISBN)
        REFERENCES Books(ISBN)
        ON UPDATE CASCADE
        ON DELETE CASCADE,
    CONSTRAINT chk_copy_status
        CHECK (Status IN ('Available', 'Borrowed', 'Lost', 'Damaged'))
);

CREATE TABLE Members (
    MemberID INT NOT NULL AUTO_INCREMENT,
    FirstName VARCHAR(100) NOT NULL,
    LastName VARCHAR(100) NOT NULL,
    Address VARCHAR(255),
    Phone VARCHAR(20),
    Email VARCHAR(150) UNIQUE,
    MembershipDate DATE NOT NULL DEFAULT (CURRENT_DATE),
    CONSTRAINT pk_members PRIMARY KEY (MemberID)
);

CREATE TABLE Librarians (
    LibrarianID INT NOT NULL AUTO_INCREMENT,
    Name VARCHAR(150) NOT NULL,
    Email VARCHAR(150) UNIQUE,
    HireDate DATE NOT NULL,
    CONSTRAINT pk_librarians PRIMARY KEY (LibrarianID)
);

CREATE TABLE Loans (
    LoanID INT NOT NULL AUTO_INCREMENT,
    CopyID INT NOT NULL,
    MemberID INT NOT NULL,
    LibrarianID INT,
    BorrowDate DATE NOT NULL DEFAULT (CURRENT_DATE),
    DueDate DATE NOT NULL,
    ReturnDate DATE,
    Status VARCHAR(20) NOT NULL DEFAULT 'Borrowed',
    Fine DECIMAL(6,2) NOT NULL DEFAULT 0.00,

    CONSTRAINT pk_loans PRIMARY KEY (LoanID),

    CONSTRAINT fk_loans_copy FOREIGN KEY (CopyID)
        REFERENCES BookCopies(CopyID)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,

    CONSTRAINT fk_loans_member FOREIGN KEY (MemberID)
        REFERENCES Members(MemberID)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,

    CONSTRAINT fk_loans_librarian FOREIGN KEY (LibrarianID)
        REFERENCES Librarians(LibrarianID)
        ON UPDATE CASCADE
        ON DELETE SET NULL,

    CONSTRAINT chk_loan_status
        CHECK (Status IN ('Borrowed', 'Returned', 'Overdue')),

    CONSTRAINT chk_return_after_borrow
        CHECK (ReturnDate IS NULL OR ReturnDate >= BorrowDate),

    CONSTRAINT chk_due_after_borrow
        CHECK (DueDate >= BorrowDate)
);

CREATE INDEX idx_loans_member ON Loans(MemberID);
CREATE INDEX idx_loans_copy ON Loans(CopyID);
CREATE INDEX idx_loans_status ON Loans(Status);
CREATE INDEX idx_copies_isbn ON BookCopies(ISBN);

DELIMITER $$

CREATE TRIGGER trg_before_loan_insert
BEFORE INSERT ON Loans
FOR EACH ROW
BEGIN
    DECLARE copy_status VARCHAR(20);

    SELECT Status INTO copy_status
    FROM BookCopies
    WHERE CopyID = NEW.CopyID;

    IF copy_status IS NULL THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Invalid CopyID: book copy does not exist.';
    ELSEIF copy_status <> 'Available' THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Book copy is not available for borrowing.';
    END IF;
END$$

CREATE TRIGGER trg_after_loan_insert
AFTER INSERT ON Loans
FOR EACH ROW
BEGIN
    UPDATE BookCopies
    SET Status = 'Borrowed'
    WHERE CopyID = NEW.CopyID;
END$$

CREATE TRIGGER trg_after_loan_update
AFTER UPDATE ON Loans
FOR EACH ROW
BEGIN
    IF NEW.ReturnDate IS NOT NULL
       AND OLD.ReturnDate IS NULL THEN
        UPDATE BookCopies
        SET Status = 'Available'
        WHERE CopyID = NEW.CopyID;
    END IF;
END$$

DELIMITER ;

INSERT INTO Books
(ISBN, Title, Author, Publisher, PubYear, Category)
VALUES
('101', 'Fundamentals of Database Systems', 'Elmasri & Navathe', 'Pearson', 2015, 'Computer Science'),
('102', 'Sapiens', 'Yuval Noah Harari', 'Harper', 2015, 'History'),
('103', 'Harry Potter and the Sorcerer''s Stone', 'J.K. Rowling', 'Scholastic', 1998, 'Fiction');

INSERT INTO BookCopies
(ISBN, ShelfLocation, Status)
VALUES
('101', 'A1-01', 'Available'),
('101', 'A1-02', 'Available'),
('102', 'A2-01', 'Available'),
('103', 'B2-11', 'Available');

INSERT INTO Members
(FirstName, LastName, Address, Phone, Email, MembershipDate)
VALUES
('Asha', 'Rao', '12 MG Road, Vijayawada', '9000011111', 'asha_rao@gmail.com', '2023-01-15'),
('Rahul', 'Menon', '45 Park Street, Kochi', '9000022222', 'rahul_menon@gmail.com', '2024-06-01');

INSERT INTO Librarians
(Name, Email, HireDate)
VALUES
('Priya Nair', 'priya.nair@gmail.com', '2020-04-01'),
('Sanjay Kumar', 'sanjay.kumar@gmail.com', '2022-09-12');

INSERT INTO Loans
(CopyID, MemberID, LibrarianID, BorrowDate, DueDate, Status)
VALUES
(1, 1, 1, CURRENT_DATE, DATE_ADD(CURRENT_DATE, INTERVAL 14 DAY), 'Borrowed');

INSERT INTO Loans
(CopyID, MemberID, LibrarianID, BorrowDate, DueDate, Status)
VALUES
(2, 2, 2, DATE_SUB(CURRENT_DATE, INTERVAL 30 DAY), DATE_SUB(CURRENT_DATE, INTERVAL 16 DAY), 'Borrowed');

UPDATE Loans
SET Status = 'Overdue'
WHERE Status = 'Borrowed'
AND DueDate < CURRENT_DATE;

UPDATE Loans
SET ReturnDate = CURRENT_DATE,
    Status = 'Returned'
WHERE LoanID = 1;

SELECT
    l.LoanID,
    m.FirstName,
    m.LastName,
    b.Title,
    bc.CopyID,
    l.BorrowDate,
    l.DueDate,
    DATEDIFF(CURRENT_DATE, l.DueDate) AS DaysOverdue
FROM Loans l
JOIN BookCopies bc ON l.CopyID = bc.CopyID
JOIN Books b ON bc.ISBN = b.ISBN
JOIN Members m ON l.MemberID = m.MemberID
WHERE l.Status = 'Overdue'
AND l.DueDate < CURRENT_DATE;

SELECT
    b.ISBN,
    b.Title,
    b.Author,
    COUNT(bc.CopyID) AS AvailableCopies
FROM Books b
JOIN BookCopies bc ON b.ISBN = bc.ISBN
WHERE bc.Status = 'Available'
GROUP BY b.ISBN, b.Title, b.Author
HAVING COUNT(bc.CopyID) > 0;

SELECT
    l.LoanID,
    b.Title,
    bc.CopyID,
    l.BorrowDate,
    l.DueDate,
    l.ReturnDate,
    l.Status,
    l.Fine
FROM Loans l
JOIN BookCopies bc ON l.CopyID = bc.CopyID
JOIN Books b ON bc.ISBN = b.ISBN
WHERE l.MemberID = 1
ORDER BY l.BorrowDate DESC;

SELECT * FROM Books;

SELECT * FROM BookCopies;

SELECT * FROM Members;

SELECT * FROM Librarians;

SELECT * FROM Loans;