use C4::Context;
use DBI;

my $dbh = C4::Context->dbh;

my $current_version= (C4::Context->preference("KohaPTFSVersion"));

if (!$current_version || ($current_version == "pre_harley")){

print "Upgrade to 'harley' beginning.\n==========\n";
print "Adding new system preferences\n";

$dbh -> do("INSERT INTO systempreferences (variable,value,explanation,options,type) VALUES ('PatronDisplayReturn','1','If ON,allows items to be returned in the patron details display checkout list.','','YesNo');");
print ".";
$dbh -> do("INSERT INTO systempreferences (variable,value,explanation,options,type) VALUES ('opacbookbagName','Cart','Allows libraries to define a different name for the OPAC Cart feature,such as Bookbag or Personal Shelf. If no name is defined,it will default to Cart.','70|10','Textarea');");
print ".";
$dbh -> do("INSERT INTO systempreferences (variable,value,explanation,options,type) VALUES ('DisplayMultiPlaceHold','1','If ON,displays the Place Hold button at the top of the search results list in staff and OPAC. Sites whose policies require tighter control over holds may want to turn this option off and limit users to placing holds one at a time.','','YesNo');");
print ".";
$dbh -> do("INSERT INTO systempreferences (variable,value,explanation,options,type) VALUES ('OPACAdvancedSearchTypes','itemtypes','Select which set of fields comprise the Type limit in the OPAC advanced search','itemtypes|ccode','Choice');");
print ".";
$dbh -> do("INSERT INTO systempreferences (variable,value,explanation,options,type) VALUES ('HoldButtonConfirm','1','Display Confirm button when hold triggered. Leave either this setting or HoldButtonPrintConfirm on.','','YesNo');");
print ".";
$dbh -> do("INSERT INTO systempreferences (variable,value,explanation,options,type) VALUES ('HoldButtonPrintConfirm','1','Display Confirm and Print Slip button when hold triggered. Leave either this setting or HoldButtonConfirm on.','','YesNo');");
print ".";
$dbh -> do("INSERT INTO systempreferences (variable,value,explanation,options,type) VALUES ('HoldButtonIgnore','1','Display Ignore button when hold triggered.','','YesNo');");
print ".";
$dbh -> do("INSERT INTO systempreferences (variable,value,explanation,options,type) VALUES ('opacmsgtab','1','If on,enables display of My Messaging tab in OPAC patron account and the email/text message settings in OPAC user update tab.','','YesNo');");
print ".";
$dbh -> do("INSERT INTO systempreferences (variable,value,explanation,options,type) VALUES ('AutoSelfCheckAllowed','0','For corporate and special libraries which want web-based self-check available from any PC without the need for a manual staff login. Most libraries will want to leave this turned off. If on,requires self-check ID and password to be entered in AutoSelfCheckID and AutoSelfCheckPass sysprefs.','','YesNo');");
print ".";
$dbh -> do("INSERT INTO systempreferences (variable,value,explanation,options,type) VALUES ('AutoSelfCheckID','','Staff ID with circulation rights to be used for automatic web-based self-check. Only applies if AutoSelfCheckAllowed syspref is turned on.','70|10','Textarea');");
print ".";
$dbh -> do("INSERT INTO systempreferences (variable,value,explanation,options,type) VALUES ('AutoSelfCheckPass','','Password to be used for automatic web-based self-check. Only applies if AutoSelfCheckAllowed syspref is turned on.','70|10','Textarea');");
print ".";
$dbh -> do("INSERT INTO systempreferences (variable,value,explanation,options,type) VALUES ('OPACFinesTab','1','If OFF the patron fines tab in the OPAC is disabled.','','YesNo');");
print ".";
$dbh -> do("INSERT INTO systempreferences (variable,value,explanation,options,type) VALUES ('EnableOverdueAccruedAmount','0','If ON,splits fines and charges into amount due and overdue accrued amount.  The latter amount can not be paid until the item is checked in.','','YesNo');");
print ".";
$dbh -> do("INSERT INTO systempreferences (variable,value,explanation,options,type) VALUES ('CircFinesBreakdown','1','Show a breakdown of fines by type on the checkout page','','YesNo');");
print ".";
$dbh -> do("INSERT INTO systempreferences (variable,value,explanation,options,type) VALUES ('EnableOwedNotification',0,'If ON,allows a notification to be sent on total amount owed.  OwedNotificationValue syspref will need to be set to the desired amount.',NULL,'YesNo');");
print ".";
$dbh -> do("INSERT INTO systempreferences (variable,value,explanation,options,type) VALUES ('OwedNotificationValue',25.00,'Amount owed to receive a notification.  To work,EnableOwedNotification syspref will need to be turned ON.',NULL,'free');");
print ".";
$dbh -> do("INSERT INTO systempreferences (variable,value,explanation,options,type)VALUES ('BCCAllNotices','','If set,sends a blind carbon of every email sent to the specified address','','free');");
print ".";
$dbh -> do("INSERT INTO systempreferences (variable,value,options,explanation,type) VALUES ('CheckoutTimeout','0','','Value in seconds before a window pops up on the circ screen asking the librarian if they would like to continue using this record or to search for a new borrower.','Integer');");
print ".";
$dbh -> do("INSERT INTO systempreferences (variable,value,options,explanation,type) VALUES ('AllowOverrideLogin','0','','If ON,Koha will allow staff members to temporarily log in as a user with more rights in certain situations','YesNo');");
print ".";
$dbh -> do("INSERT INTO systempreferences (variable,value,options,explanation,type) VALUES ('AllowDueDateInPast','0','','Allows a due date to be set in the past for testing.','YesNo');");
print ".";
$dbh -> do("INSERT INTO systempreferences (variable,value,options,explanation,type) VALUES ('AllowCheckInDateChange','1','','Allow modification of checkin date/time','YesNo');");
print ".";
$dbh -> do("INSERT INTO systempreferences (variable,value,options,explanation,type) VALUES ('BatchMemberDeleteFineThreshhold','0.0','','Any borrower with an amount of fines greater than this value cannot be deleted via batch borrower deleting.','Float');");
print ".";
$dbh -> do("INSERT INTO systempreferences (variable,value,options,explanation,type) VALUES ('ShowPatronSearchBySQL','0','','If turned on,a search by sql box will appear on the Patrons search pages.','YesNo');");
print ".";
$dbh -> do("INSERT INTO systempreferences (variable,value,options,explanation,type) VALUES ('BatchMemberDeletePaidDebtCollections','0','','If on,the batch delete will refuse to delete members with unpaid fines before being put in debt collections.','YesNo');");
print ".";
$dbh -> do("INSERT INTO systempreferences (variable,value,options,explanation,type) VALUES ('DisableHoldsIssueOverrideUnlessAuthorised','1','','If this preference is enabled,it will block staff ability to checkout items on hold,but includes a superlibrarian override.','YesNo');");
print ".";
$dbh -> do("INSERT INTO systempreferences (variable,value,options,explanation,type) VALUES ('UseGranularMaxFines','0','','If enabled,this allows you to define the max for an item by a combination of itemtype & patroncategory.','YesNo');");
print ".";
$dbh -> do("INSERT INTO systempreferences (variable,value,options,explanation,type) VALUES ('UseGranularMaxHolds','0','','If enabled,this allows you to define the maximum number of holds by a combination of itemtype & patroncategory.','YesNo');");
print ".";
$dbh -> do("INSERT INTO systempreferences (variable,value,options,explanation,type) VALUES ('WarnOnlyOnMaxFine','0','','If UseGranularMaxFines and WarnOnlyOnMaxFine are both enabled,fine warnings will only occur when the fine for an item hits the max_fine attribute set in issuingrules.','YesNo');");
print ".";
$dbh -> do("INSERT INTO systempreferences (variable,value,options,explanation,type) VALUES ('DisplayInitials','1','','Ability to turn the initials field on/off in patron screen','YesNo');");
print ".";
$dbh -> do("INSERT INTO systempreferences (variable,value,options,explanation,type) VALUES ('DisplayOthernames','1','','Ability to turn the othernames field on/off in patron screen','YesNo');");
$dbh -> do("INSERT INTO systempreferences (variable,value,options,explanation,type) VALUES ('AllowReadingHistoryAnonymizing','1','','Allows a borrower to optionally delete his or her reading history.','YesNo');");
print ".";
$dbh -> do("INSERT INTO systempreferences (variable,value,options,explanation,type) VALUES ('ClaimsReturnedValue','','','Lost value of Claims Returned,to be ignored by fines cron job','Integer');");
print ".";
$dbh -> do("INSERT INTO systempreferences (variable,value,options,explanation,type) VALUES ('MarkLostItemsReturned',0,'','If ON,will check in items (removing them from a patron list of checked out items) when they are marked as lost','YesNo');");
print ".";
$dbh -> do("INSERT INTO systempreferences (variable,value,options,explanation,type) VALUES ('ResetOpacInactivityTimeout','0','','This will set an inactivity timer that will reset the OPAC to the main OPAC screen after the specified amount of time has passed since mouse movement was last detected. The value is 0 for disabled,or a positive integer for the number of seconds of inactivity before resetting the OPAC.','Integer');");
print ".";
$dbh -> do("INSERT INTO systempreferences (variable,value,options,explanation,type) VALUES ('AllowMultipleHoldsPerBib','','','This allows multiple items per record to be placed on hold by a single patron. To enable,enter a list of space separated itemtype codes in the field (i.e. MAG JMAG YMAG). Useful for magazines,encyclopedias and other bibs where the attached items are not identical.','');");
print ".";
print "done!\n";
print "==========\n";

print "Modifying reserves table structure\n";
$dbh -> do("ALTER TABLE reserves ADD COLUMN reservenumber int(11) NOT NULL FIRST;");
print ".";
$dbh -> do("ALTER TABLE reserves ADD COLUMN expirationdate date;");
print ".";
$dbh -> do("ALTER TABLE reserves ADD PRIMARY KEY (reservenumber);");
print ".";
print "done!\n";
print "==========\n";

print "Modifying old_reserves table structure\n";
$dbh -> do("ALTER TABLE old_reserves ADD COLUMN reservenumber int(11) NOT NULL FIRST;");
print ".";
$dbh -> do("ALTER TABLE old_reserves ADD COLUMN expirationdate date;");
print ".";
$dbh -> do("ALTER TABLE old_reserves ADD PRIMARY KEY (reservenumber);");
print ".";
$dbh -> do("ALTER TABLE old_reserves DROP FOREIGN KEY old_reserves_ibfk_3;");
print ".";
print "done!\n";
print "==========\n";


print "Creating reserves_suspended table\n";
$dbh -> do(" 
CREATE TABLE reserves_suspended (
    reservenumber int(11) NOT NULL,
    borrowernumber int(11) NOT NULL default 0,
    reservedate date default NULL,
    biblionumber int(11) NOT NULL default 0,
    constrainttype varchar(1) default NULL,
    branchcode varchar(10) default NULL,
    notificationdate date default NULL,
    reminderdate date default NULL,
    cancellationdate date default NULL,
    reservenotes mediumtext,
    priority smallint(6) default NULL,
    found varchar(1) default NULL,
    timestamp timestamp NOT NULL default CURRENT_TIMESTAMP on update CURRENT_TIMESTAMP,
    itemnumber int(11) default NULL,
    waitingdate date default NULL,
    expriationdate date,
    PRIMARY KEY  (reservenumber),
    KEY borrowernumber (borrowernumber),
    KEY biblionumber (biblionumber),
    KEY itemnumber (itemnumber),
    KEY branchcode (branchcode),
    CONSTRAINT reserves_suspended_ibfk_1 FOREIGN KEY (borrowernumber) REFERENCES borrowers (borrowernumber) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT reserves_suspended_ibfk_2 FOREIGN KEY (biblionumber) REFERENCES biblio (biblionumber) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT reserves_suspended_ibfk_4 FOREIGN KEY (branchcode) REFERENCES branches (branchcode) ON DELETE CASCADE ON UPDATE CASCADE
  ) ENGINE=InnoDB DEFAULT CHARSET=utf8;
");
print ".";
print "done!\n";
print "==========\n";

print "Updating Z39.50 servers for NYU and NYPL\n";
$dbh -> do("DELETE FROM z3950servers where name='NEW YORK UNIVERSITY LIBRARIES' or name='NEW YORK PUBLIC LIBRARY';");
print ".";
$dbh -> do("
INSERT INTO z3950servers
 (host, port, db, userid, password, name, id, checked, rank, syntax, encoding) VALUES 
 ('hopkins1.bobst.nyu.edu',9991,'NYU01PUB','','','NEW YORK UNIVERSITY LIBRARIES',5,0,0,'USMARC','MARC-8'),
 ('catalog.nypl.org',210,'innopac','','','NEW YORK PUBLIC LIBRARY',7,0,0,'USMARC','MARC-8');
");
print ".";
print "done!\n";
print "==========\n";

print "Updating permissions table with granular permissions\n";
$dbh -> do("TRUNCATE permissions;");
print ".";
$dbh -> do("
INSERT INTO permissions (module_bit, code, description) VALUES
   ( 1, 'circulate_remaining_permissions', 'Remaining circulation permissions'),
   ( 1, 'override_renewals', 'Override blocked renewals'),
   ( 1, 'exempt_fines', 'User can activate exempt fines in Check In'),
   ( 1, 'bookdrop', 'User can activate bookdrop mode in Check In'),
   ( 1, 'override_checkout_max', 'User can override the checkout maximum'),
   ( 1, 'override_non_circ', 'User can override the not for loan check'),
   ( 1, 'override_max_fines', 'User can override block for patron over max fine limit'),
   ( 1, 'change_lost_status', 'User can set the item lost status'),
   ( 1, 'change_due_date', 'User can specify a due date other than in the circulation rules'),
   ( 1, 'view_borrower_name_in_checkin', 'User can see the borrower name in Check In'),
   ( 1, 'view_checkout', 'view items checked out to a borrower in checkin/checkout'),
   ( 1, 'change_circ_date_and_time', 'User can change circulation date and time'),
   ( 1, 'fast_add', 'User can use fast add functionality in checkout' ),
   ( 1, 'renew_expired', 'User can renew an expired borrower in checkout'),
   ( 4, 'view_borrowers', 'View a borrower record'),
   ( 4, 'add_borrowers', 'Add a borrower record'),
   ( 4, 'delete_borrowers', 'User can delete borrower record'),
   ( 4, 'edit_borrowers', 'User can edit borrower record'),
   ( 4, 'edit_borrower_circnote', 'User can edit the contents of the borrower circulation note'),
   ( 4, 'edit_borrower_opacnote', 'User can edit the contents of the borrower opac note'),
   ( 6, 'delete_holds', 'User can delete hold requests from circulation'),
   ( 6, 'edit_holds', 'User can edit hold requests'),
   ( 6, 'view_holds', 'User can view hold requests'),
   ( 6, 'add_holds', 'User may place a hold for a borrower'),
   ( 6, 'reorder_holds', 'User can reorder hold requests'),
   ( 6, 'delete_waiting_holds', 'User can delete holds from the waiting for pickup list'),
   ( 9, 'view', 'User may view bibliographic and item information'),
   ( 9, 'add_bibliographic', 'Create a bibliographic record'),
   ( 9, 'edit_bibliographic', 'Edit a bibliographic record'),
   ( 9, 'delete_bibliographic', 'Delete a bibliographic record'),
   ( 9, 'batch_edit_items','Batch item editor'),
   ( 9, 'add_items', 'Create or copy a new item'),
   ( 9, 'delete_items', 'Delete an item'),
   ( 9, 'edit_items', 'Edit an item record'),
   (10, 'view_charges', 'View borrower charges'),
   (10, 'add_charges', 'Add a charge to a patron record'),
   (10, 'edit_charges', 'User can change a fee record'),
   (10, 'accept_payment', 'User can accept payment from a borrower'),
   (10, 'writeoff_charges', 'User can writeoff a charge'),
   (13, 'edit_news', 'Write news for the OPAC and staff interfaces'),
   (13, 'label_creator', 'Create printable labels and barcodes from catalog and patron data'),
   (13, 'edit_calendar', 'Define days when the library is closed'),
   (13, 'moderate_comments', 'Moderate patron comments'),
   (13, 'edit_notices', 'Define notices'),
   (13, 'edit_notice_status_triggers', 'Set notice/status triggers for overdue items'),
   (13, 'view_system_logs', 'Browse the system logs'),
   (13, 'inventory', 'Perform inventory (stocktaking) of your catalogue'),
   (13, 'stage_marc_import', 'Stage MARC records into the reservoir'),
   (13, 'manage_staged_marc', 'Managed staged MARC records, including completing and reversing imports'),
   (13, 'export_catalog', 'Export bibliographic and holdings data'),
   (13, 'import_patrons', 'Import patron data'),
   (13, 'delete_anonymize_patrons', 'Delete old borrowers and anonymize circulation history (deletes borrower reading history)'),
   (13, 'batch_upload_patron_images', 'Upload patron images in batch or one at a time'),
   (13, 'batch_edit_items', 'User can access the batch edit items function'),
   (13, 'schedule_tasks', 'Schedule tasks to run');
");
print ".";
print "done!\n";
print "==========\n";


print "Adding new letter for damaged-item hold cancellation\n";
$dbh -> do("INSERT INTO letter (module,code,name,title,content) VALUES ('reserves','DAMAGEDHOLD','Damaged Item Removed From Holds Queue','Damaged Item Removed From Holds Queue','The following item was returned damaged and is out of circulation; your hold has been cancelled.\r\n\r\n<<biblio.title>>\r\n\r\n');");
print ".";
print "done!\n";
print "==========\n";

print "Adding new message transport for print notices\n";
$dbh -> do("INSERT INTO message_transport_types (message_transport_type) values ('print');");
print ".";
print "done!\n";
print "==========\n";

print "Altering borrowers table structure\n";
$dbh -> do("ALTER TABLE borrowers ADD COLUMN disable_reading_history tinyint(1) default NULL;");
print ".";
$dbh -> do("ALTER TABLE borrowers ADD COLUMN amount_notify_date date;");
print ".";
$dbh -> do("ALTER TABLE deletedborrowers ADD COLUMN disable_reading_history tinyint(1) default NULL;");
print ".";
$dbh -> do("ALTER TABLE deletedborrowers ADD COLUMN amount_notify_date date;");
print ".";
print "done!\n";
print "==========\n";


print "Altering issuingrules table structure\n";
$dbh -> do("ALTER TABLE issuingrules ADD COLUMN max_fine decimal(28,6) default NULL;");
print ".";
$dbh -> do("ALTER TABLE issuingrules ADD COLUMN holdallowed tinyint(1) DEFAULT 2;");
print ".";
$dbh -> do("ALTER TABLE issuingrules ADD COLUMN max_holds int(4) default NULL;");
print ".";
print "done!\n";
print "==========\n";

print "Creating new tables for import profiles\n";
$dbh -> do("
CREATE TABLE import_profiles (
  profile_id int(11) AUTO_INCREMENT,
  description varchar(50) NOT NULL,
  matcher_id int(11) DEFAULT NULL,
  template_id int(11) DEFAULT NULL,
  overlay_action enum('replace','create_new','use_template','ignore') NOT NULL DEFAULT 'create_new',
  nomatch_action enum('create_new','ignore') NOT NULL DEFAULT 'create_new',
  parse_items tinyint(1) DEFAULT 1,
  item_action enum('always_add','add_only_for_matches','add_only_for_new','ignore') NOT NULL DEFAULT 'always_add',
  PRIMARY KEY (profile_id),
  KEY (description)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
");
print ".";
$dbh -> do("
CREATE TABLE import_profile_added_items (
  profile_id int(11) DEFAULT NULL,
  marcxml text COLLATE utf8_general_ci NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
");
print ".";
$dbh -> do("
CREATE TABLE import_profile_subfield_actions (
  profile_id int(11) NOT NULL DEFAULT '0',
  tag char(3) COLLATE utf8_general_ci NOT NULL DEFAULT '',
  subfield char(1) COLLATE utf8_general_ci NOT NULL DEFAULT '',
  action enum('add_always','add','delete') COLLATE utf8_general_ci DEFAULT NULL,
  contents varchar(255) COLLATE utf8_general_ci DEFAULT NULL,
  PRIMARY KEY (profile_id,tag,subfield),
  CONSTRAINT import_profile_subfield_actions_ibfk_1 FOREIGN KEY (profile_id) REFERENCES import_profiles (profile_id) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
");
print ".";
print "done!\n";
print "==========\n";

print "Altering itemtypes structure\n";
$dbh -> do("ALTER TABLE itemtypes ADD COLUMN reservefee decimal(28,6);");
print ".";
print "done!\n";
print "==========\n";

print "Creating new table for overdue rules by item type\n";
$dbh -> do("
CREATE TABLE overdueitemrules (
  branchcode varchar(10) NOT NULL default '',
  itemtype varchar(10) NOT NULL default '',
  delay1 int(4) default 0,
  letter1 varchar(20) default NULL,
  debarred1 varchar(1) default 0,
  delay2 int(4) default 0,
  debarred2 varchar(1) default 0,
  letter2 varchar(20) default NULL,
  delay3 int(4) default 0,
  letter3 varchar(20) default NULL,
  debarred3 int(1) default 0,
  PRIMARY KEY  (branchcode,itemtype)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
");
print ".";
print "done!\n";
print "==========\n";

print "Creating new table for batch item delete list tool\n";
$dbh -> do("
CREATE TABLE itemdeletelist ( 
  list_id int(11) not null, 
  itemnumber int(11) not null, 
  biblionumber int(11) not null, 
  PRIMARY KEY (list_id,itemnumber)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
");
print ".";
print "done!\n";
print "==========\n";

print "Creating and populating new table for additional item statuses\n";
$dbh -> do("
CREATE TABLE itemstatus (
  statuscode_id int(11) NOT NULL auto_increment,
  statuscode varchar(10) NOT NULL default '',
  description varchar(25) default NULL,
  holdsallowed tinyint(1) NOT NULL default 0,
  holdsfilled tinyint(1) NOT NULL default 0,
  PRIMARY KEY  (statuscode_id),
  UNIQUE KEY statuscode (statuscode)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
");
print ".";
$dbh -> do("INSERT INTO itemstatus (statuscode,description,holdsallowed,holdsfilled) VALUES ('','','0','0');");
print ".";
$dbh -> do("INSERT INTO itemstatus (statuscode,description,holdsallowed,holdsfilled) VALUES ('cat','Cataloging','1','1');");
print ".";
$dbh -> do("INSERT INTO itemstatus (statuscode,description,holdsallowed,holdsfilled) VALUES ('conya','Coming off New/YA','1','1');");
print ".";
$dbh -> do("INSERT INTO itemstatus (statuscode,description,holdsallowed,holdsfilled) VALUES ('cooj','Coming off O/J','1','1');");
print ".";
$dbh -> do("INSERT INTO itemstatus (statuscode,description,holdsallowed,holdsfilled) VALUES ('coryd','Coming Off R/Y Dot','1','1');");
print ".";
$dbh -> do("INSERT INTO itemstatus (statuscode,description,holdsallowed,holdsfilled) VALUES ('da','Display Area','1','1');");
print ".";
$dbh -> do("INSERT INTO itemstatus (statuscode,description,holdsallowed,holdsfilled) VALUES ('dc','YS Display','1','1');");
print ".";
$dbh -> do("INSERT INTO itemstatus (statuscode,description,holdsallowed,holdsfilled) VALUES ('mc','Media Cleaning','1','1');");
print ".";
$dbh -> do("INSERT INTO itemstatus (statuscode,description,holdsallowed,holdsfilled) VALUES ('n','Newly Acquired','1','1');");
print ".";
$dbh -> do("INSERT INTO itemstatus (statuscode,description,holdsallowed,holdsfilled) VALUES ('oflow','Overflow','1','1');");
print ".";
$dbh -> do("INSERT INTO itemstatus (statuscode,description,holdsallowed,holdsfilled) VALUES ('re','IN REPAIRS','1','1');");
print ".";
$dbh -> do("INSERT INTO itemstatus (statuscode,description,holdsallowed,holdsfilled) VALUES ('res','Reserved','1','0');");
print ".";
$dbh -> do("INSERT INTO itemstatus (statuscode,description,holdsallowed,holdsfilled) VALUES ('s','Shelving Cart','1','1');");
print ".";
$dbh -> do("INSERT INTO itemstatus (statuscode,description,holdsallowed,holdsfilled) VALUES ('scd','Senior Center Display','1','1');");
print ".";
$dbh -> do("INSERT INTO itemstatus (statuscode,description,holdsallowed,holdsfilled) VALUES ('st','Storage','0','0');");
print ".";
$dbh -> do("INSERT INTO itemstatus (statuscode,description,holdsallowed,holdsfilled) VALUES ('t','In Cataloging','1','1');");
print ".";
$dbh -> do("INSERT INTO itemstatus (statuscode,description,holdsallowed,holdsfilled) VALUES ('trace','Trace','1','1');");
print ".";
$dbh -> do("INSERT INTO itemstatus (statuscode,description,holdsallowed,holdsfilled) VALUES ('ufa','fast add item','1','0');");
print ".";
$dbh -> do("INSERT INTO itemstatus (statuscode,description,holdsallowed,holdsfilled) VALUES ('url','Online','0','0');");
print ".";
$dbh -> do("INSERT INTO itemstatus (statuscode,description,holdsallowed,holdsfilled) VALUES ('yso','YS Office','0','0');");
print ".";
print "done!\n";
print "==========\n";

print "Altering items table structure\n";
$dbh -> do("ALTER TABLE items ADD COLUMN otherstatus varchar(10);");
print ".";
$dbh -> do("ALTER TABLE items ADD COLUMN suppress tinyint(1) NOT NULL DEFAULT 0 AFTER wthdrawn;");
print ".";
$dbh -> do("ALTER TABLE deleteditems ADD COLUMN otherstatus varchar(10);");
print ".";
$dbh -> do("ALTER TABLE deleteditems ADD COLUMN suppress tinyint(1) NOT NULL DEFAULT 0 AFTER wthdrawn;");
print ".";
print "done!\n";
print "==========\n";

print "Adding authorised values for item suppression\n";
$dbh -> do("
INSERT into authorised_values 
(category,authorised_value, lib, imageurl) VALUES
('I_SUPPRESS',0,'Do not Suppress',''),
('I_SUPPRESS',1,'Suppress','');
");
print ".";
print "done!\n";
print "==========\n";

print "Altering MARC subfield structure for item suppression and other item status\n";
my $frames_sth = $dbh -> prepare("SELECT frameworkcode FROM biblio_framework");

my $insert_sth = $dbh -> prepare("
INSERT INTO marc_subfield_structure 
  (tagfield, tagsubfield, liblibrarian, libopac, repeatable, mandatory, kohafield, tab, authorised_value, authtypecode, value_builder, isurl, hidden, frameworkcode, seealso, link, defaultvalue) 
  VALUES 
  ('952', 'i', 'Supressed','',0,0,'items.suppress',-1,'I_SUPPRESS','','',0,0,?,NULL,'','');
");
my $insert_sth_2 = $dbh ->prepare("
INSERT INTO marc_subfield_structure 
  (tagfield, tagsubfield, liblibrarian, libopac, repeatable, mandatory, kohafield, tab, authorised_value, authtypecode, value_builder, isurl, hidden, frameworkcode, seealso, link, defaultvalue) 
  VALUES 
  ('952', 'k', 'Other item status', 'Other item status', 0, 0, 'items.otherstatus', 10, 'otherstatus', '', '', 0, 0, ?, NULL, '', '');
");

$frames_sth->execute;
  while (my $frame = $frames_sth->fetchrow_hashref) {

    $insert_sth -> execute($frame->{frameworkcode});
    $insert_sth_2 -> execute($frame->{frameworkcode});

    print ".";
  }
print "done!\n";
print "==========\n";

print "Creating and populating Clubs and Services tables\n";
$dbh -> do("
CREATE TABLE clubsAndServices (
   casId int(11) NOT NULL auto_increment,
   casaId int(11) NOT NULL default '0' COMMENT 'foreign key to clubsAndServicesArchetypes',
   title text NOT NULL,
   description text,
   casData1 text COMMENT 'Data described in casa.casData1Title',
   casData2 text COMMENT 'Data described in casa.casData2Title',
   casData3 text COMMENT 'Data described in casa.casData3Title',
   startDate date NOT NULL default '0000-00-00',
   endDate date default NULL,
   branchcode varchar(4) NOT NULL COMMENT 'branch where club or service was created.',
   last_updated timestamp NOT NULL default CURRENT_TIMESTAMP,
   PRIMARY KEY  (casId)
) ENGINE=MyISAM  DEFAULT CHARSET=utf8;
");
print ".";
$dbh -> do("
CREATE TABLE clubsAndServicesArchetypes (
   casaId int(11) NOT NULL auto_increment,
   type enum('club','service') NOT NULL default 'club',
   title text NOT NULL COMMENT 'title of this archetype',
   description text NOT NULL COMMENT 'long description of this archetype',
   publicEnrollment tinyint(1) NOT NULL default '0' COMMENT 'If 1, patron should be able to enroll in club or service from OPAC, if 0, only a librarian should be able to enroll a patron in the club or service.',
   casData1Title text COMMENT 'Title of contents in cas.data1',
   casData2Title text COMMENT 'Title of contents in cas.data2',
   casData3Title text COMMENT 'Title of contents in cas.data3',
   caseData1Title text COMMENT 'Name of what is stored in cAsE.data1',
   caseData2Title text COMMENT 'Name of what is stored in cAsE.data2',
   caseData3Title text COMMENT 'Name of what is stored in cAsE.data3',
   casData1Desc text,
   casData2Desc text,
   casData3Desc text,
   caseData1Desc text,
   caseData2Desc text,
   caseData3Desc text,
   caseRequireEmail tinyint(1) NOT NULL default '0',
   branchcode varchar(4) default NULL COMMENT 'branch where archetype was created.',
   last_updated timestamp NOT NULL default CURRENT_TIMESTAMP,
   PRIMARY KEY  (casaId)
) ENGINE=MyISAM  DEFAULT CHARSET=utf8;
");
print ".";
$dbh -> do("
INSERT INTO clubsAndServicesArchetypes ( type,title,description,publicEnrollment,casData1Title,casData2Title,casData3Title,caseData1Title,caseData2Title,caseData3Title,casData1Desc,casData2Desc,casData3Desc,caseData1Desc,caseData2Desc,caseData3Desc   )
VALUES 
  ('club', 'Bestsellers Club', 'This club archetype gives the patrons the ability join a club for a given author and for staff to batch generate a holds list which shuffles the holds queue when specific titles or books by certain authors are received.', '0', 'Title', 'Author', 'Item Types', '', '', '', 'If filled in, the the club will only apply to books where the title matches this field. Must be identical to the MARC field mapped to title.', 'If filled in, the the club will only apply to books where the author matches this field. Must be identical to the MARC field mapped to author.', 'Put a list of space separated Item Types here for that this club should work for. Leave it blank for all item types.', '', '', '' ),
  ('service', 'New Items E-mail List', 'This club archetype gives the patrons the ability join a mailing list which will e-mail weekly lists of new items for the given itemtype and callnumber combination given.', 0, 'Itemtype', 'Callnumber', NULL, NULL, NULL, NULL, 'The Itemtype to be looked up. Use % for all itemtypes.', 'The callnumber to look up. Use % as wildcard.', NULL, NULL, NULL, NULL);
");
print ".";
$dbh ->do("
CREATE TABLE clubsAndServicesEnrollments (
   caseId int(11) NOT NULL auto_increment,
   casaId int(11) NOT NULL default '0' COMMENT 'foreign key to clubsAndServicesArchtypes',
   casId int(11) NOT NULL default '0' COMMENT 'foreign key to clubsAndServices',
   borrowernumber int(11) NOT NULL default '0' COMMENT 'foreign key to borrowers',
   data1 text COMMENT 'data described in casa.data1description',
   data2 text,
   data3 text,
   dateEnrolled date NOT NULL default '0000-00-00' COMMENT 'date borrowers service begins',
   dateCanceled date default NULL COMMENT 'date borrower decided to end service',
   last_updated timestamp NOT NULL default CURRENT_TIMESTAMP,
   branchcode varchar(4) default NULL COMMENT 'foreign key to branches',
   PRIMARY KEY  (caseId)
) ENGINE=MyISAM  DEFAULT CHARSET=utf8;
");
print ".";
print "done!\n";
print "==========\n";

print <<EOF
Remaining tasks must be done manually!

You have to modify your Zebra configuration, adding one line to each of three 
files  The line can be at the end of the file, in each case.  For a "dev" 
install, ZEBRADIR is at ~/koha-dev/etc/zebradb

In $ZEBRADIR/biblios/etc/bib1.att:
att 8033    suppress

In $ZEBRADIR/ccl.properties:
suppress 1=8033

In $ZEBRADIR/marc_defs/marc21/biblios/record.abs:
melm 952$i suppress,suppress:n

If you don't mind overlaying your current indexing configuration, you can copy those three files from your kohaclone/etc/zebradb tree.

Then suppress one item in the staff interface, and reindex.  (You can then un-suppress the item.)
EOF
;

if (!$current_version) {
   $dbh -> do("INSERT INTO systempreferences (variable,value,explanation,options,type) VALUES ('KohaPTFSVersion','harley','Currently installed PTFS version information','','free');");
} else {
   $dbh -> do("UPDATE systempreferences SET value='harley' WHERE variable='KohaPTFSVersion'");
}

}

$current_version= (C4::Context->preference("KohaPTFSVersion"));

if ($current_version == "harley"){

print "Upgrade to 'ptfs-master 1.1' beginning.\n==========\n";
print "Adding new system preferences\n";
$dbh->do("INSERT INTO systempreferences (variable,value,explanation,type) VALUES ('DisplayStafficonsXSLT','0',
     'If ON, displays the format, audience, type icons in the staff XSLT MARC21 result and display pages.','YesNo')");
print ".";
$dbh->do("INSERT INTO `systempreferences` (variable,value,options,explanation,type) VALUES ('CourseReserves','0','',
      'Turn ON Course Reserves functionality','YesNo');");
print ".";
$dbh -> do("INSERT INTO systempreferences (variable,value,explanation,options,type) VALUES ('Replica_DSN','',
    'DSN for reporting database replica','','Textarea');");
print ".";
$dbh -> do("INSERT INTO systempreferences (variable,value,explanation,options,type) VALUES ('Replica_user','',
    'Username for reporting database replica','','Textarea');");
print ".";
$dbh -> do("INSERT INTO systempreferences (variable,value,explanation,options,type) VALUES ('Replica_pass','',
    'Password for reporting database replica','','Textarea');");
print ".";
print "done!\n";
print "==========\n";

print "Adding new tables for course reserves\n";
$dbh->do("DROP TABLE IF EXISTS `courses`;");
$dbh->do("CREATE TABLE `courses` (
        `course_id` INT(11) NOT NULL auto_increment,
        `department` VARCHAR(20),       -- req, auth value
        `course_number` VARCHAR(255),    -- req, free text
        `section` VARCHAR(255),          -- free text
        `course_name` VARCHAR(255),      -- req, free text
        `term` VARCHAR(20),             -- req, auth value
        `staff_note` mediumtext,
        `public_note` mediumtext,
        `students_count` VARCHAR(20),
        `course_status` enum('enabled','disabled') NOT NULL DEFAULT 'enabled',
        `timestamp` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY (`course_id`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8;");
print ".";
$dbh->do("DROP TABLE IF EXISTS `instructor_course_link`;");
$dbh->do("CREATE TABLE `instructor_course_link` (
        `instructor_course_link_id` INT(11) NOT NULL auto_increment,
        `course_id` INT(11) NOT NULL default 0,
        `instructor_borrowernumber` INT(11) NOT NULL default 0,
        PRIMARY KEY (`instructor_course_link_id`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8;");
print ".";
$dbh->do("DROP TABLE IF EXISTS `course_reserves`;");
$dbh->do("CREATE TABLE `course_reserves` (
        `course_reserve_id` INT(11) NOT NULL auto_increment,
        `course_id` INT(11) NOT NULL,
        `itemnumber` INT(11) NOT NULL,
        `staff_note` mediumtext,
        `public_note` mediumtext,
        `itemtype` VARCHAR(10) default NULL,
        `ccode` VARCHAR(10) default NULL,
        `location` varchar(80) default NULL,
        `branchcode` varchar(10) NOT NULL,
        `original_itemtype` VARCHAR(10) default NULL,
        `original_ccode` VARCHAR(10) default NULL,
        `original_branchcode` varchar(10) NOT NULL,
        `original_location` varchar(80) default NULL,
        `timestamp` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY (`course_reserve_id`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8;");
print ".";
print "done!\n";
print "==========\n";

print "Adding new authorised values and permissions for course reserves\n";
$dbh->do("INSERT INTO `authorised_values` ( category, authorised_value, lib ) values ( 'DEPARTMENT', 'Default', 'Default Department' );");
print ".";
$dbh->do("INSERT INTO `authorised_values` ( category, authorised_value, lib ) values ( 'TERM', 'Default', 'Default Term' );");
print ".";
$dbh->do("INSERT INTO permissions (module_bit,code,description) VALUES 
     ( 1, 'manage_courses', 'View, Create, Edit and Delete Courses'), 
     ( 1, 'put_coursereserves', 'Basic Course Reserves access,  user can put items on course reserve'), 
     ( 1, 'remove_coursereserves', 'Take items off course reserve'), 
     ( 1, 'checkout_via_proxy', 'Checkout via Proxy'), 
     ( 4, 'create_proxy_relationships', 'Create Proxy Relationships'), 
     ( 4, 'edit_proxy_relationships', 'Edit Proxy Relationships'), 
     ( 4, 'delete_proxy_relationships', 'Delete Proxy Relationships');");
print ".";
print "done!\n";
print "==========\n";

print "Altering MARC subfield structure for curriculum indexing\n";
my $frames_sth = $dbh -> prepare("SELECT frameworkcode FROM biblio_framework");

my $insert_sth = $dbh -> prepare("
INSERT INTO marc_subfield_structure
  (tagfield, tagsubfield, liblibrarian, libopac, repeatable, mandatory, kohafield, tab, authorised_value, authtypecode, value_builder, isurl, hidden, frameworkcode, seealso, link, defaultvalue)
  VALUES
               ('658', 'a', 'Main curriculum objective', 'Main curriculum objective', 0, 0, '', 6, '', 'TOPIC_TERM', '', NULL, 0, ?, '', '', NULL);
");
my $insert_sth_2 = $dbh ->prepare("
INSERT INTO marc_subfield_structure
  (tagfield, tagsubfield, liblibrarian, libopac, repeatable, mandatory, kohafield, tab, authorised_value, authtypecode, value_builder, isurl, hidden, frameworkcode, seealso, link, defaultvalue)
  VALUES
               ('658', 'b', 'Subordinate curriculum objective', 'Subordinate curriculum objective', 1, 0, '', 6, '', '', '', NULL, 0, ?, '', '', NULL);
");
my $insert_sth_3 = $dbh ->prepare("
INSERT INTO marc_subfield_structure
  (tagfield, tagsubfield, liblibrarian, libopac, repeatable, mandatory, kohafield, tab, authorised_value, authtypecode, value_builder, isurl, hidden, frameworkcode, seealso, link, defaultvalue)
  VALUES
               ('658', 'c', 'Curriculum code', 'Curriculum code', 0, 0, '', 6, '', '', '', NULL, 0, ?, '', '', NULL);
");
my $insert_sth_4 = $dbh ->prepare("
INSERT INTO marc_tag_structure
  (tagfield, liblibrarian,libopac,repeatable,mandatory,authorised_value,frameworkcode)
  VALUES
     ('658','SUBJECT--CURRICULUM OBJECTIVE','SUBJECT--CURRICULUM OBJECTIVE',1,0,NULL,?);
");

$frames_sth->execute;
  while (my $frame = $frames_sth->fetchrow_hashref) {

    $insert_sth -> execute($frame->{frameworkcode});
    $insert_sth_2 -> execute($frame->{frameworkcode});
    $insert_sth_3 -> execute($frame->{frameworkcode});
    $insert_sth_4 -> execute($frame->{frameworkcode});

    print ".";
  }
print "done!\n";
print "==========\n";
print <<EOF2
Remaining tasks must be done manually!

You have to modify your Zebra configuration, adding lines to each of three 
files  The lines can be at the end of the file, in each case.  For a "dev" 
install, ZEBRADIR is at ~/koha-dev/etc/zebradb

In $ZEBRADIR/biblios/etc/bib1.att:
att 9658    curriculum

In $ZEBRADIR/ccl.properties:
curriculum 1=9658

In $ZEBRADIR/marc_defs/marc21/biblios/record.abs:
melm 658$a     curriculum:w,curriculum:p
melm 658$b     curriculum:w,curriculum:p
melm 658$c     curriculum:w,curriculum:p

If you don't mind overlaying your current indexing configuration, you can copy those three files from your kohaclone/etc/zebradb tree.

Then, reindex the database.
EOF2
;

$dbh -> do("UPDATE systempreferences SET value='PTFS1.1' WHERE variable='KohaPTFSVersion'");
}
