--  <- these are to give spacing so the code is slightly easier to read (this type of comenting may not work on all types of SQL DBMS'S)

--Tables & Values--
--
CREATE TABLE Config (
 CompanyName				TEXT NOT NULL,
 CompanyAddress				TEXT NOT NULL,
 CompanyPhoneNumber			NUMERIC(20,2) NOT NULL,
 VATRate					DECIMAL NOT NULL DEFAULT 0.2
);
--


--
CREATE TABLE Clients (
 ClientID					SERIAL CONSTRAINT ClientID_ZERO CHECK (ClientID > 0),
 ContactNames				TEXT NOT NULL,
 ContactsCompany			TEXT NOT NULL,
 BillingAddress				TEXT NOT NULL,
 PhoneNumbers				NUMERIC(20, 2) NOT NULL,
 MobileNumbers				NUMERIC(20, 2),
 FaxNumbers					NUMERIC(20, 2),
 EmailAddresses				TEXT,
 Notes						TEXT,
 
 CONSTRAINT Clients_PRIMARY_KEY PRIMARY KEY (ClientID));
--


--
CREATE TABLE Employees (
 EmployeeID					SERIAL CONSTRAINT EmployeeID_ZERO CHECK (EmployeeID > 0),
 FirstName					TEXT NOT NULL,
 LastName					TEXT NOT NULL,
 Address					TEXT NOT NULL,
 EmailAddress				TEXT,
 PhoneNumber				NUMERIC(20, 2) NOT NULL,
 HourlyPayRate				NUMERIC(10, 2) NOT NULL,
 HourlyBillingRate			NUMERIC(10, 2) NOT NULL,

 CONSTRAINT Employees_PRIMARY_KEY PRIMARY KEY ( EmployeeID));
--


--
CREATE TABLE Estimates (
 EstimateID					SERIAL CONSTRAINT EstimateID_ZERO CHECK (EstimateID > 0),
 ClientID					INTEGER NOT NULL CONSTRAINT ClientID_ZERO CHECK (ClientID > 0),
 DateIssued					DATE NOT NULL,
 JobDescription				TEXT NOT NULL,
 HourlyorTotalorBoth		CHAR(10) NOT NULL,
 HourlyCharge				NUMERIC(20, 2) NOT NULL CONSTRAINT HourlyCharge_ZERO CHECK (HourlyCharge >= 0),
 TotalCharge				NUMERIC(20, 2) NOT NULL CONSTRAINT TotalCharge_ZERO CHECK (TotalCharge >= 0),
 Conditionals				TEXT,
 Notes						TEXT,
 
 CONSTRAINT EstimatesCID_FOREIGN_KEY FOREIGN KEY (ClientID) REFERENCES Clients (ClientID),
 CONSTRAINT Estimates_PRIMARY_KEY PRIMARY KEY (EstimateID));
--


--
CREATE TABLE WorkOrder (
 WorkOrderID				SERIAL CONSTRAINT WorkOrderID_ZERO CHECK (WorkOrderID > 0),
 EstimateID					INTEGER NOT NULL CONSTRAINT EstimateID_ZERO CHECK (EstimateID > 0),
 ApprovedOrDisapproved		CHAR(12) NOT NULL,
 DateApprovedOrDisapproved	DATE NOT NULL,
 Notes						TEXT,
 
 CONSTRAINT WorkOrderEID_FOREIGN_KEY FOREIGN KEY (EstimateID) REFERENCES Estimates (EstimateID),
 CONSTRAINT WorkOrderID_PRIMARY_KEY PRIMARY KEY (WorkOrderID));
--


--
CREATE TABLE WorkLog (
 WorkLogID					SERIAL CONSTRAINT WorkLogID_ZERO CHECK (WorkLogID > 0),
 EmployeeID					INTEGER NOT NULL CONSTRAINT EmployeeID_ZERO CHECK (EmployeeID > 0),
 WorkOrderID				INTEGER NOT NULL CONSTRAINT WorkOrderID_ZERO CHECK (WorkOrderID > 0),
 DateofJob					DATE NOT NULL,
 CurrentJobForThisHour		TEXT NOT NULL,
 HoursWorked				NUMERIC(20, 2) NOT NULL,
 
 CONSTRAINT WorkLogEID_FOREIGN_KEY FOREIGN KEY (EmployeeID) REFERENCES Employees (EmployeeID),
 CONSTRAINT WorkLogWOID_FOREIGN_KEY FOREIGN KEY (WorkOrderID) REFERENCES WorkOrder (WorkOrderID),
 CONSTRAINT WorkLog_PRIMARY_KEY PRIMARY KEY (WorkLogID));
--


--
CREATE TABLE Invoices (
 InvoiceID					SERIAL CONSTRAINT InvoiceID_ZERO CHECK (InvoiceID > 0),
 WorkLogID					INTEGER NOT NULL CONSTRAINT WorkLogID_ZERO CHECK (WorkLogID > 0),
 WorkOrderID				INTEGER NOT NULL CONSTRAINT WorkOrderID_ZERO CHECK (WorkOrderID > 0),
 ClientID					INTEGER NOT NULL CONSTRAINT ClientID_ZERO CHECK (ClientID > 0),
 InvoiceDate				DATE NOT NULL,
 Terms						TEXT,
 DetailsofCharges			TEXT NOT NULL,
 SubTotal					NUMERIC(20, 2) NOT NULL CONSTRAINT SubTotal_ZERO CHECK (SubTotal >= 0) DEFAULT 0,

 CONSTRAINT InvoicesWLID_FOREIGN_KEY FOREIGN KEY (WorkLogID) REFERENCES WorkLog (WorkLogID),
 CONSTRAINT InvoicesWOID_FOREIGN_KEY FOREIGN KEY (WorkOrderID) REFERENCES WorkOrder (WorkOrderID),
 CONSTRAINT InvoicesCID_FOREIGN_KEY FOREIGN KEY (ClientID) REFERENCES Clients (ClientID),
 CONSTRAINT Invoices_PRIMARY_KEY PRIMARY KEY (InvoiceID));
--


--Audit--
CREATE TABLE WorkLogAudit(
 WorkLogAuditID				SERIAL CONSTRAINT WorkLogAuditID_ZERO CHECK (WorkLogAuditID > 0),
 EmployeeID					INTEGER NOT NULL,
 WorkOrderID				INTEGER NOT NULL,
 DateofJob					DATE NOT NULL,
 CurrentJobForThisHour		TEXT NOT NULL,
 HoursWorked				NUMERIC(20, 2) NOT NULL,
 Action         			CHAR(6) NOT NULL,
 Occurred            		TIMESTAMP NOT NULL,
 
 CONSTRAINT WorkLogAudit_PRIMARY_KEY PRIMARY KEY (WorkLogAuditID));

 
CREATE OR REPLACE FUNCTION trig_WorkLogAudit() RETURNS TRIGGER AS $WorkLogAudit$
    BEGIN
        IF (TG_OP = 'DELETE') THEN
			INSERT INTO WorkLogAudit(WorkLogAuditID,EmployeeID,WorkOrderID,DateofJob,CurrentJobForThisHour,HoursWorked,Action,Occurred)
			VALUES (old.WorkLogID,old.EmployeeID,old.WorkOrderID,old.DateofJob,old.CurrentJobForThisHour,old.HoursWorked, tg_op, NOW());
            RETURN OLD;
        ELSIF (TG_OP = 'UPDATE') THEN
            INSERT INTO WorkLogAudit(WorkLogAuditID,EmployeeID,WorkOrderID,DateofJob,CurrentJobForThisHour,HoursWorked,Action,Occurred)
			VALUES (old.WorkLogID,old.EmployeeID,old.WorkOrderID,old.DateofJob,old.CurrentJobForThisHour,old.HoursWorked, tg_op, NOW());
            RETURN NEW;
        ELSIF (TG_OP = 'INSERT') THEN
            INSERT INTO WorkLogAudit(WorkLogAuditID,EmployeeID,WorkOrderID,DateofJob,CurrentJobForThisHour,HoursWorked,Action,Occurred)
			VALUES (new.WorkLogID,new.EmployeeID,new.WorkOrderID,new.DateofJob,new.CurrentJobForThisHour,new.HoursWorked, tg_op, NOW());
            RETURN NEW;
        END IF;
        RETURN NULL;
    END;
$WorkLogAudit$ LANGUAGE plpgsql;

CREATE TRIGGER WorkLogAudit
AFTER INSERT OR UPDATE OR DELETE ON WorkLog
    FOR EACH ROW EXECUTE PROCEDURE trig_WorkLogAudit();
--
	

--Views--

--
CREATE VIEW ApprovedWorkOrdersViewer AS
SELECT WorkOrder.WorkOrderID,Estimates.ClientID,ContactNames,ContactsCompany,DateIssued,JobDescription,HourlyorTotalorBoth,HourlyCharge,TotalCharge,Conditionals,
ApprovedOrDisapproved,DateApprovedOrDisapproved,DateofJob,CurrentJobForThisHour,HoursWorked,Estimates.Notes
FROM WorkLog,WorkOrder,Estimates,Clients
WHERE WorkOrder.EstimateID = Estimates.EstimateID
AND Clients.ClientID = Estimates.ClientID
AND WorkLog.WorkOrderID = WorkOrder.WorkOrderID;
--

--
CREATE VIEW DisApprovedWorkOrdersViewer AS
SELECT WorkOrder.WorkOrderID,Estimates.ClientID,ContactNames,ContactsCompany,DateIssued,JobDescription,HourlyorTotalorBoth,HourlyCharge,TotalCharge,Conditionals,
ApprovedOrDisapproved,DateApprovedOrDisapproved,DateofJob,CurrentJobForThisHour,HoursWorked,Estimates.Notes
FROM WorkLog,WorkOrder,Estimates,Clients
WHERE WorkOrder.EstimateID = Estimates.EstimateID
AND Clients.ClientID = Estimates.ClientID
AND WorkLog.WorkOrderID = WorkOrder.WorkOrderID;
--

--
CREATE VIEW WorkLogsViewer AS
SELECT WorkLog.WorkOrderID,WorkLog.EmployeeID,FirstName,LastName,DateofJob,CurrentJobForThisHour,HoursWorked
FROM Employees,WorkOrder,WorkLog
WHERE Employees.EmployeeID = WorkLog.EmployeeID
AND WorkOrder.WorkOrderID = WorkLog.WorkOrderID;
--

--
CREATE VIEW InvoicesViewer AS
SELECT CompanyName,CompanyAddress,Invoices.InvoiceID,Invoices.WorkorderID,invoices.ClientID,ContactNames,ContactsCompany,BillingAddress,Terms,InvoiceDate,DetailsofCharges,SubTotal,VATRate,VATRate*SubTotal AS VAT,(VATRate*SubTotal)+SubTotal AS Total
FROM Invoices,WorkOrder,Clients,Config
WHERE Invoices.WorkorderID = Workorder.WorkorderID
AND Clients.ClientID = invoices.ClientID;
--

--
CREATE VIEW SalesReport AS
SELECT InvoiceID,Invoices.ClientID,ContactNames,InvoiceDate,SubTotal,VATRate,VATRate*SubTotal AS VAT,(VATRate*SubTotal)+SubTotal AS Total
FROM Invoices,Clients,Config
WHERE Invoices.ClientID = Clients.ClientID;
--

--
CREATE VIEW EmployeeLogReport AS
SELECT WorkLog.EmployeeID,FirstName,LastName,WorkLog.WorkOrderID,DateofJob,HoursWorked,HourlyPayRate,HoursWorked*HourlyPayRate AS Total
FROM WorkLog,WorkOrder,Employees
WHERE Employees.EmployeeID = WorkLog.EmployeeID
AND WorkOrder.WorkOrderID = WorkLog.WorkOrderID;
--