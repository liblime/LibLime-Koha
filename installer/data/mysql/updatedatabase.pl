#!/usr/bin/env perl


# Database Updater
# This script checks for required updates to the database.

# Part of the Koha Library Software www.koha.org
# Licensed under the GPL.

# Bugs/ToDo:
# - Would also be a good idea to offer to do a backup at this time...

# NOTE:  If you do something more than once in here, make it table driven.

use strict;
use warnings;

# CPAN modules
use DBI;
use Getopt::Long;
# Koha modules
use Koha;
use C4::Context;
use C4::Installer;

use MARC::Record;
use MARC::File::XML ( BinaryEncoding => 'utf8' );
 
# FIXME - The user might be installing a new database, so can't rely
# on /etc/koha.conf anyway.

my $debug = 0;

my (
    $sth, $sti,
    $query,
    %existingtables,    # tables already in database
    %types,
    $table,
    $column,
    $type, $null, $key, $default, $extra,
    $prefitem,          # preference item in systempreferences table
);

my $silent;
GetOptions(
    's' =>\$silent
    );
my $dbh = C4::Context->dbh;
$dbh->{RaiseError} = 0;
$|=1; # flushes output

=item

    Deal with virtualshelves

=cut

my $DBversion = "3.00.00.001";
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
    # update virtualshelves table to
    # 
    $dbh->do("ALTER TABLE `bookshelf` RENAME `virtualshelves`");
    $dbh->do("ALTER TABLE `shelfcontents` RENAME `virtualshelfcontents`");
    $dbh->do("ALTER TABLE `virtualshelfcontents` ADD `biblionumber` INT( 11 ) NOT NULL default '0' AFTER shelfnumber");
    $dbh->do("UPDATE `virtualshelfcontents` SET biblionumber=(SELECT biblionumber FROM items WHERE items.itemnumber=virtualshelfcontents.itemnumber)");
    # drop all foreign keys : otherwise, we can't drop itemnumber field.
    DropAllForeignKeys('virtualshelfcontents');
    $dbh->do("ALTER TABLE `virtualshelfcontents` ADD KEY biblionumber (biblionumber)");
    # create the new foreign keys (on biblionumber)
    $dbh->do("ALTER TABLE `virtualshelfcontents` ADD CONSTRAINT `virtualshelfcontents_ibfk_1` FOREIGN KEY (`shelfnumber`) REFERENCES `virtualshelves` (`shelfnumber`) ON DELETE CASCADE ON UPDATE CASCADE");
    # re-create the foreign key on virtualshelf
    $dbh->do("ALTER TABLE `virtualshelfcontents` ADD CONSTRAINT `shelfcontents_ibfk_2` FOREIGN KEY (`biblionumber`) REFERENCES `biblio` (`biblionumber`) ON DELETE CASCADE ON UPDATE CASCADE");
    $dbh->do("ALTER TABLE `virtualshelfcontents` DROP `itemnumber`");
    print "Upgrade to $DBversion done (virtualshelves)\n";
    SetVersion ($DBversion);
}


$DBversion = "3.00.00.002";
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
    $dbh->do("DROP TABLE sessions");
    $dbh->do("CREATE TABLE `sessions` (
  `id` varchar(32) NOT NULL,
  `a_session` text NOT NULL,
  UNIQUE KEY `id` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;");
    print "Upgrade to $DBversion done (sessions uses CGI::session, new table structure for sessions)\n";
    SetVersion ($DBversion);
}


$DBversion = "3.00.00.003";
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
    if (C4::Context->preference("opaclanguages") eq "fr") {
        $dbh->do("INSERT INTO `systempreferences` (variable,value,explanation,options,type) VALUES('ReservesNeedReturns','0','Si ce paramètre est mis à 1, une réservation posée sur un exemplaire présent sur le site devra être passée en retour pour être disponible. Sinon, elle sera automatiquement disponible, Koha considère que le bibliothécaire place la réservation en ayant le document en mains','','YesNo')");
    } else {
        $dbh->do("INSERT INTO `systempreferences` (variable,value,explanation,options,type) VALUES('ReservesNeedReturns','0','If set, a reserve done on an item available in this branch need a check-in, otherwise, a reserve on a specific item, that is on the branch & available is considered as available','','YesNo')");
    }
    print "Upgrade to $DBversion done (adding ReservesNeedReturns systempref, in circulation)\n";
    SetVersion ($DBversion);
}


$DBversion = "3.00.00.004";
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
    $dbh->do("INSERT INTO `systempreferences` VALUES ('DebugLevel','2','set the level of error info sent to the browser. 0=none, 1=some, 2=most','0|1|2','Choice')");    
    print "Upgrade to $DBversion done (adding DebugLevel systempref, in 'Admin' tab)\n";
    SetVersion ($DBversion);
}

$DBversion = "3.00.00.005";
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
    $dbh->do("CREATE TABLE `tags` (
                    `entry` varchar(255) NOT NULL default '',
                    `weight` bigint(20) NOT NULL default 0,
                    PRIMARY KEY  (`entry`)
                    ) ENGINE=InnoDB DEFAULT CHARSET=utf8;
                ");
        $dbh->do("CREATE TABLE `nozebra` (
                `server` varchar(20)     NOT NULL,
                `indexname` varchar(40)  NOT NULL,
                `value` varchar(250)     NOT NULL,
                `biblionumbers` longtext NOT NULL,
                KEY `indexname` (`server`,`indexname`),
                KEY `value` (`server`,`value`))
                ENGINE=InnoDB DEFAULT CHARSET=utf8;
                ");
    print "Upgrade to $DBversion done (adding tags and nozebra tables )\n";
    SetVersion ($DBversion);
}

$DBversion = "3.00.00.006";
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
    $dbh->do("UPDATE issues SET issuedate=timestamp WHERE issuedate='0000-00-00'");
    print "Upgrade to $DBversion done (filled issues.issuedate with timestamp)\n";
    SetVersion ($DBversion);
}

$DBversion = "3.00.00.007";
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
    $dbh->do("INSERT INTO systempreferences (variable,value,explanation,options,type) VALUES ('SessionStorage','mysql','Use mysql or a temporary file for storing session data','mysql|tmp','Choice')");
    print "Upgrade to $DBversion done (set SessionStorage variable)\n";
    SetVersion ($DBversion);
}

$DBversion = "3.00.00.008";
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
    $dbh->do("ALTER TABLE `biblio` ADD `datecreated` DATE NOT NULL AFTER `timestamp` ;");
    $dbh->do("UPDATE biblio SET datecreated=timestamp");
    print "Upgrade to $DBversion done (biblio creation date)\n";
    SetVersion ($DBversion);
}

$DBversion = "3.00.00.009";
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {

    # Create backups of call number columns
    # in case default migration needs to be customized
    #
    # UPGRADE NOTE: temp_upg_biblioitems_call_num should be dropped 
    #               after call numbers have been transformed to the new structure
    #
    # Not bothering to do the same with deletedbiblioitems -- assume
    # default is good enough.
    $dbh->do("CREATE TABLE `temp_upg_biblioitems_call_num` AS 
              SELECT `biblioitemnumber`, `biblionumber`,
                     `classification`, `dewey`, `subclass`,
                     `lcsort`, `ccode`
              FROM `biblioitems`");

    # biblioitems changes
    $dbh->do("ALTER TABLE `biblioitems` CHANGE COLUMN `volumeddesc` `volumedesc` TEXT,
                                    ADD `cn_source` VARCHAR(10) DEFAULT NULL AFTER `ccode`,
                                    ADD `cn_class` VARCHAR(30) DEFAULT NULL AFTER `cn_source`,
                                    ADD `cn_item` VARCHAR(10) DEFAULT NULL AFTER `cn_class`,
                                    ADD `cn_suffix` VARCHAR(10) DEFAULT NULL AFTER `cn_item`,
                                    ADD `cn_sort` VARCHAR(30) DEFAULT NULL AFTER `cn_suffix`,
                                    ADD `totalissues` INT(10) AFTER `cn_sort`");

    # default mapping of call number columns:
    #   cn_class = concatentation of classification + dewey, 
    #              trimmed to fit -- assumes that most users do not
    #              populate both classification and dewey in a single record
    #   cn_item  = subclass
    #   cn_source = left null 
    #   cn_sort = lcsort 
    #
    # After upgrade, cn_sort will have to be set based on whatever
    # default call number scheme user sets as a preference.  Misc
    # script will be added at some point to do that.
    #
    $dbh->do("UPDATE `biblioitems` 
              SET cn_class = SUBSTR(TRIM(CONCAT_WS(' ', `classification`, `dewey`)), 1, 30),
                    cn_item = subclass,
                    `cn_sort` = `lcsort`
            ");

    # Now drop the old call number columns
    $dbh->do("ALTER TABLE `biblioitems` DROP COLUMN `classification`,
                                        DROP COLUMN `dewey`,
                                        DROP COLUMN `subclass`,
                                        DROP COLUMN `lcsort`,
                                        DROP COLUMN `ccode`");

    # deletedbiblio changes
    $dbh->do("ALTER TABLE `deletedbiblio` ALTER COLUMN `frameworkcode` SET DEFAULT '',
                                        DROP COLUMN `marc`,
                                        ADD `datecreated` DATE NOT NULL AFTER `timestamp`");
    $dbh->do("UPDATE deletedbiblio SET datecreated = timestamp");

    # deletedbiblioitems changes
    $dbh->do("ALTER TABLE `deletedbiblioitems` 
                        MODIFY `publicationyear` TEXT,
                        CHANGE `volumeddesc` `volumedesc` TEXT,
                        MODIFY `collectiontitle` MEDIUMTEXT DEFAULT NULL AFTER `volumedesc`,
                        MODIFY `collectionissn` TEXT DEFAULT NULL AFTER `collectiontitle`,
                        MODIFY `collectionvolume` MEDIUMTEXT DEFAULT NULL AFTER `collectionissn`,
                        MODIFY `editionstatement` TEXT DEFAULT NULL AFTER `collectionvolume`,
                        MODIFY `editionresponsibility` TEXT DEFAULT NULL AFTER `editionstatement`,
                        MODIFY `place` VARCHAR(255) DEFAULT NULL AFTER `size`,
                        MODIFY `marc` LONGBLOB,
                        ADD `cn_source` VARCHAR(10) DEFAULT NULL AFTER `url`,
                        ADD `cn_class` VARCHAR(30) DEFAULT NULL AFTER `cn_source`,
                        ADD `cn_item` VARCHAR(10) DEFAULT NULL AFTER `cn_class`,
                        ADD `cn_suffix` VARCHAR(10) DEFAULT NULL AFTER `cn_item`,
                        ADD `cn_sort` VARCHAR(30) DEFAULT NULL AFTER `cn_suffix`,
                        ADD `totalissues` INT(10) AFTER `cn_sort`,
                        ADD `marcxml` LONGTEXT NOT NULL AFTER `totalissues`,
                        ADD KEY `isbn` (`isbn`),
                        ADD KEY `publishercode` (`publishercode`)
                    ");

    $dbh->do("UPDATE `deletedbiblioitems` 
                SET `cn_class` = SUBSTR(TRIM(CONCAT_WS(' ', `classification`, `dewey`)), 1, 30),
               `cn_item` = `subclass`,
                `cn_sort` = `lcsort`
            ");
    $dbh->do("ALTER TABLE `deletedbiblioitems` 
                        DROP COLUMN `classification`,
                        DROP COLUMN `dewey`,
                        DROP COLUMN `subclass`,
                        DROP COLUMN `lcsort`,
                        DROP COLUMN `ccode`
            ");

    # deleteditems changes
    $dbh->do("ALTER TABLE `deleteditems` 
                        MODIFY `barcode` VARCHAR(20) DEFAULT NULL,
                        MODIFY `price` DECIMAL(8,2) DEFAULT NULL,
                        MODIFY `replacementprice` DECIMAL(8,2) DEFAULT NULL,
                        DROP `bulk`,
                        MODIFY `itemcallnumber` VARCHAR(30) DEFAULT NULL AFTER `wthdrawn`,
                        MODIFY `holdingbranch` VARCHAR(10) DEFAULT NULL,
                        DROP `interim`,
                        MODIFY `timestamp` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP on update CURRENT_TIMESTAMP AFTER `paidfor`,
                        DROP `cutterextra`,
                        ADD `cn_source` VARCHAR(10) DEFAULT NULL AFTER `onloan`,
                        ADD `cn_sort` VARCHAR(30) DEFAULT NULL AFTER `cn_source`,
                        ADD `ccode` VARCHAR(10) DEFAULT NULL AFTER `cn_sort`,
                        ADD `materials` VARCHAR(10) DEFAULT NULL AFTER `ccode`,
                        ADD `uri` VARCHAR(255) DEFAULT NULL AFTER `materials`,
                        MODIFY `marc` LONGBLOB AFTER `uri`,
                        DROP KEY `barcode`,
                        DROP KEY `itembarcodeidx`,
                        DROP KEY `itembinoidx`,
                        DROP KEY `itembibnoidx`,
                        ADD UNIQUE KEY `delitembarcodeidx` (`barcode`),
                        ADD KEY `delitembinoidx` (`biblioitemnumber`),
                        ADD KEY `delitembibnoidx` (`biblionumber`),
                        ADD KEY `delhomebranch` (`homebranch`),
                        ADD KEY `delholdingbranch` (`holdingbranch`)");
    $dbh->do("UPDATE deleteditems SET `ccode` = `itype`");
    $dbh->do("ALTER TABLE deleteditems DROP `itype`");
    $dbh->do("UPDATE `deleteditems` SET `cn_sort` = `itemcallnumber`");

    # items changes
    $dbh->do("ALTER TABLE `items` ADD `cn_source` VARCHAR(10) DEFAULT NULL AFTER `onloan`,
                                ADD `cn_sort` VARCHAR(30) DEFAULT NULL AFTER `cn_source`,
                                ADD `ccode` VARCHAR(10) DEFAULT NULL AFTER `cn_sort`,
                                ADD `materials` VARCHAR(10) DEFAULT NULL AFTER `ccode`,
                                ADD `uri` VARCHAR(255) DEFAULT NULL AFTER `materials`
            ");
    $dbh->do("ALTER TABLE `items` 
                        DROP KEY `itembarcodeidx`,
                        ADD UNIQUE KEY `itembarcodeidx` (`barcode`)");

    # map items.itype to items.ccode and 
    # set cn_sort to itemcallnumber -- as with biblioitems.cn_sort,
    # will have to be subsequently updated per user's default 
    # classification scheme
    $dbh->do("UPDATE `items` SET `cn_sort` = `itemcallnumber`,
                            `ccode` = `itype`");

    $dbh->do("ALTER TABLE `items` DROP `cutterextra`,
                                DROP `itype`");

    print "Upgrade to $DBversion done (major changes to biblio, biblioitems, items, and deleted* versions of same\n";
    SetVersion ($DBversion);
}

$DBversion = "3.00.00.010";
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
    $dbh->do("CREATE INDEX `userid` ON borrowers (`userid`) ");
    print "Upgrade to $DBversion done (userid index added)\n";
    SetVersion ($DBversion);
}

$DBversion = "3.00.00.011";
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
    $dbh->do("ALTER TABLE `branchcategories` CHANGE `categorycode` `categorycode` varchar(10) ");
    $dbh->do("ALTER TABLE `branchcategories` CHANGE `categoryname` `categoryname` varchar(32) ");
    $dbh->do("ALTER TABLE `branchcategories` ADD COLUMN `categorytype` varchar(16) ");
    $dbh->do("UPDATE `branchcategories` SET `categorytype` = 'properties'");
    $dbh->do("ALTER TABLE `branchrelations` CHANGE `categorycode` `categorycode` varchar(10) ");
    print "Upgrade to $DBversion done (added branchcategory type)\n";
    SetVersion ($DBversion);
}

$DBversion = "3.00.00.012";
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
    $dbh->do("CREATE TABLE `class_sort_rules` (
                               `class_sort_rule` varchar(10) NOT NULL default '',
                               `description` mediumtext,
                               `sort_routine` varchar(30) NOT NULL default '',
                               PRIMARY KEY (`class_sort_rule`),
                               UNIQUE KEY `class_sort_rule_idx` (`class_sort_rule`)
                             ) ENGINE=InnoDB DEFAULT CHARSET=utf8");
    $dbh->do("CREATE TABLE `class_sources` (
                               `cn_source` varchar(10) NOT NULL default '',
                               `description` mediumtext,
                               `used` tinyint(4) NOT NULL default 0,
                               `class_sort_rule` varchar(10) NOT NULL default '',
                               PRIMARY KEY (`cn_source`),
                               UNIQUE KEY `cn_source_idx` (`cn_source`),
                               KEY `used_idx` (`used`),
                               CONSTRAINT `class_source_ibfk_1` FOREIGN KEY (`class_sort_rule`) 
                                          REFERENCES `class_sort_rules` (`class_sort_rule`)
                             ) ENGINE=InnoDB DEFAULT CHARSET=utf8");
    $dbh->do("INSERT INTO `systempreferences` (variable,value,explanation,options,type) 
              VALUES('DefaultClassificationSource','ddc',
                     'Default classification scheme used by the collection. E.g., Dewey, LCC, etc.', NULL,'free')");
    $dbh->do("INSERT INTO `class_sort_rules` (`class_sort_rule`, `description`, `sort_routine`) VALUES
                               ('dewey', 'Default filing rules for DDC', 'Dewey'),
                               ('lcc', 'Default filing rules for LCC', 'LCC'),
                               ('generic', 'Generic call number filing rules', 'Generic')");
    $dbh->do("INSERT INTO `class_sources` (`cn_source`, `description`, `used`, `class_sort_rule`) VALUES
                            ('ddc', 'Dewey Decimal Classification', 1, 'dewey'),
                            ('lcc', 'Library of Congress Classification', 1, 'lcc'),
                            ('udc', 'Universal Decimal Classification', 0, 'generic'),
                            ('sudocs', 'SuDoc Classification (U.S. GPO)', 0, 'generic'),
                            ('z', 'Other/Generic Classification Scheme', 0, 'generic')");
    print "Upgrade to $DBversion done (classification sources added)\n";
    SetVersion ($DBversion);
}

$DBversion = "3.00.00.013";
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
    $dbh->do("CREATE TABLE `import_batches` (
              `import_batch_id` int(11) NOT NULL auto_increment,
              `template_id` int(11) default NULL,
              `branchcode` varchar(10) default NULL,
              `num_biblios` int(11) NOT NULL default 0,
              `num_items` int(11) NOT NULL default 0,
              `upload_timestamp` timestamp NOT NULL default CURRENT_TIMESTAMP,
              `overlay_action` enum('replace', 'create_new', 'use_template') NOT NULL default 'create_new',
              `import_status` enum('staging', 'staged', 'importing', 'imported', 'reverting', 'reverted', 'cleaned') NOT NULL default 'staging',
              `batch_type` enum('batch', 'z3950') NOT NULL default 'batch',
              `file_name` varchar(100),
              `comments` mediumtext,
              PRIMARY KEY (`import_batch_id`),
              KEY `branchcode` (`branchcode`)
              ) ENGINE=InnoDB DEFAULT CHARSET=utf8");
    $dbh->do("CREATE TABLE `import_records` (
              `import_record_id` int(11) NOT NULL auto_increment,
              `import_batch_id` int(11) NOT NULL,
              `branchcode` varchar(10) default NULL,
              `record_sequence` int(11) NOT NULL default 0,
              `upload_timestamp` timestamp NOT NULL default CURRENT_TIMESTAMP,
              `import_date` DATE default NULL,
              `marc` longblob NOT NULL,
              `marcxml` longtext NOT NULL,
              `marcxml_old` longtext NOT NULL,
              `record_type` enum('biblio', 'auth', 'holdings') NOT NULL default 'biblio',
              `overlay_status` enum('no_match', 'auto_match', 'manual_match', 'match_applied') NOT NULL default 'no_match',
              `status` enum('error', 'staged', 'imported', 'reverted', 'items_reverted') NOT NULL default 'staged',
              `import_error` mediumtext,
              `encoding` varchar(40) NOT NULL default '',
              `z3950random` varchar(40) default NULL,
              PRIMARY KEY (`import_record_id`),
              CONSTRAINT `import_records_ifbk_1` FOREIGN KEY (`import_batch_id`)
                          REFERENCES `import_batches` (`import_batch_id`) ON DELETE CASCADE ON UPDATE CASCADE,
              KEY `branchcode` (`branchcode`),
              KEY `batch_sequence` (`import_batch_id`, `record_sequence`)
              ) ENGINE=InnoDB DEFAULT CHARSET=utf8");
    $dbh->do("CREATE TABLE `import_record_matches` (
              `import_record_id` int(11) NOT NULL,
              `candidate_match_id` int(11) NOT NULL,
              `score` int(11) NOT NULL default 0,
              CONSTRAINT `import_record_matches_ibfk_1` FOREIGN KEY (`import_record_id`) 
                          REFERENCES `import_records` (`import_record_id`) ON DELETE CASCADE ON UPDATE CASCADE,
              KEY `record_score` (`import_record_id`, `score`)
              ) ENGINE=InnoDB DEFAULT CHARSET=utf8");
    $dbh->do("CREATE TABLE `import_biblios` (
              `import_record_id` int(11) NOT NULL,
              `matched_biblionumber` int(11) default NULL,
              `control_number` varchar(25) default NULL,
              `original_source` varchar(25) default NULL,
              `title` varchar(128) default NULL,
              `author` varchar(80) default NULL,
              `isbn` varchar(14) default NULL,
              `issn` varchar(9) default NULL,
              `has_items` tinyint(1) NOT NULL default 0,
              CONSTRAINT `import_biblios_ibfk_1` FOREIGN KEY (`import_record_id`) 
                          REFERENCES `import_records` (`import_record_id`) ON DELETE CASCADE ON UPDATE CASCADE,
              KEY `matched_biblionumber` (`matched_biblionumber`),
              KEY `title` (`title`),
              KEY `isbn` (`isbn`)
              ) ENGINE=InnoDB DEFAULT CHARSET=utf8");
    $dbh->do("CREATE TABLE `import_items` (
              `import_items_id` int(11) NOT NULL auto_increment,
              `import_record_id` int(11) NOT NULL,
              `itemnumber` int(11) default NULL,
              `branchcode` varchar(10) default NULL,
              `status` enum('error', 'staged', 'imported', 'reverted') NOT NULL default 'staged',
              `marcxml` longtext NOT NULL,
              `import_error` mediumtext,
              PRIMARY KEY (`import_items_id`),
              CONSTRAINT `import_items_ibfk_1` FOREIGN KEY (`import_record_id`) 
                          REFERENCES `import_records` (`import_record_id`) ON DELETE CASCADE ON UPDATE CASCADE,
              KEY `itemnumber` (`itemnumber`),
              KEY `branchcode` (`branchcode`)
              ) ENGINE=InnoDB DEFAULT CHARSET=utf8");

    $dbh->do("INSERT INTO `import_batches`
                (`overlay_action`, `import_status`, `batch_type`, `file_name`)
              SELECT distinct 'create_new', 'staged', 'z3950', `file`
              FROM   `marc_breeding`");

    $dbh->do("INSERT INTO `import_records`
                (`import_batch_id`, `import_record_id`, `record_sequence`, `marc`, `record_type`, `status`,
                `encoding`, `z3950random`, `marcxml`, `marcxml_old`)
              SELECT `import_batch_id`, `id`, 1, `marc`, 'biblio', 'staged', `encoding`, `z3950random`, '', ''
              FROM `marc_breeding`
              JOIN `import_batches` ON (`file_name` = `file`)");

    $dbh->do("INSERT INTO `import_biblios`
                (`import_record_id`, `title`, `author`, `isbn`)
              SELECT `import_record_id`, `title`, `author`, `isbn`
              FROM   `marc_breeding`
              JOIN   `import_records` ON (`import_record_id` = `id`)");

    $dbh->do("UPDATE `import_batches` 
              SET `num_biblios` = (
              SELECT COUNT(*)
              FROM `import_records`
              WHERE `import_batch_id` = `import_batches`.`import_batch_id`
              )");

    $dbh->do("DROP TABLE `marc_breeding`");

    print "Upgrade to $DBversion done (import_batches et al. added)\n";
    SetVersion ($DBversion);
}

$DBversion = "3.00.00.014";
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
    $dbh->do("ALTER TABLE subscription ADD lastbranch VARCHAR(4)");
    print "Upgrade to $DBversion done (userid index added)\n";
    SetVersion ($DBversion);
}

$DBversion = "3.00.00.015"; 
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
    $dbh->do("CREATE TABLE `saved_sql` (
           `id` int(11) NOT NULL auto_increment,
           `borrowernumber` int(11) default NULL,
           `date_created` datetime default NULL,
           `last_modified` datetime default NULL,
           `savedsql` text,
           `last_run` datetime default NULL,
           `report_name` varchar(255) default NULL,
           `type` varchar(255) default NULL,
           `notes` text,
           PRIMARY KEY  (`id`),
           KEY boridx (`borrowernumber`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8;");
    $dbh->do("CREATE TABLE `saved_reports` (
           `id` int(11) NOT NULL auto_increment,
           `report_id` int(11) default NULL,
           `report` longtext,
           `date_run` datetime default NULL,
           PRIMARY KEY  (`id`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8;");
    print "Upgrade to $DBversion done (saved_sql and saved_reports added)\n";
    SetVersion ($DBversion);
}

$DBversion = "3.00.00.016"; 
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
    $dbh->do(" CREATE TABLE reports_dictionary (
          id int(11) NOT NULL auto_increment,
          name varchar(255) default NULL,
          description text,
          date_created datetime default NULL,
          date_modified datetime default NULL,
          saved_sql text,
          area int(11) default NULL,
          PRIMARY KEY  (id)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8 ");
    print "Upgrade to $DBversion done (reports_dictionary) added)\n";
    SetVersion ($DBversion);
}   

$DBversion = "3.00.00.017";
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
    $dbh->do("ALTER TABLE action_logs DROP PRIMARY KEY");
    $dbh->do("ALTER TABLE action_logs ADD KEY  timestamp (timestamp,user)");
    $dbh->do("ALTER TABLE action_logs ADD action_id INT(11) NOT NULL FIRST");
    $dbh->do("UPDATE action_logs SET action_id = if (\@a, \@a:=\@a+1, \@a:=1)");
    $dbh->do("ALTER TABLE action_logs MODIFY action_id INT(11) NOT NULL AUTO_INCREMENT PRIMARY KEY");
    print "Upgrade to $DBversion done (added column to action_logs)\n";
    SetVersion ($DBversion);
}

$DBversion = "3.00.00.019";
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
    $dbh->do("ALTER TABLE `zebraqueue` 
                    ADD `done` INT NOT NULL DEFAULT '0',
                    ADD `time` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ; 
            ");
    print "Upgrade to $DBversion done (adding timestamp and done columns to zebraque table to improve problem tracking) added)\n";
    SetVersion ($DBversion);
}   

$DBversion = "3.00.00.019";
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
    $dbh->do("ALTER TABLE biblio MODIFY biblionumber INT(11) NOT NULL AUTO_INCREMENT");
    $dbh->do("ALTER TABLE biblioitems MODIFY biblioitemnumber INT(11) NOT NULL AUTO_INCREMENT");
    $dbh->do("ALTER TABLE items MODIFY itemnumber INT(11) NOT NULL AUTO_INCREMENT");
    print "Upgrade to $DBversion done (made bib/item PKs auto_increment)\n";
    SetVersion ($DBversion);
}

$DBversion = "3.00.00.020";
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
    $dbh->do("ALTER TABLE deleteditems 
              DROP KEY `delitembarcodeidx`,
              ADD KEY `delitembarcodeidx` (`barcode`)");
    print "Upgrade to $DBversion done (dropped uniqueness of key on deleteditems.barcode)\n";
    SetVersion ($DBversion);
}

$DBversion = "3.00.00.021";
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
    $dbh->do("ALTER TABLE items CHANGE homebranch homebranch VARCHAR(10)");
    $dbh->do("ALTER TABLE deleteditems CHANGE homebranch homebranch VARCHAR(10)");
    $dbh->do("ALTER TABLE statistics CHANGE branch branch VARCHAR(10)");
    $dbh->do("ALTER TABLE subscription CHANGE lastbranch lastbranch VARCHAR(10)");
    print "Upgrade to $DBversion done (extended missed branchcode columns to 10 chars)\n";
    SetVersion ($DBversion);
}   

$DBversion = "3.00.00.022";
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
    $dbh->do("ALTER TABLE items 
                ADD `damaged` tinyint(1) default NULL AFTER notforloan");
    $dbh->do("ALTER TABLE deleteditems 
                ADD `damaged` tinyint(1) default NULL AFTER notforloan");
    print "Upgrade to $DBversion done (adding damaged column to items table)\n";
    SetVersion ($DBversion);
}

$DBversion = "3.00.00.023";
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
     $dbh->do("INSERT INTO `systempreferences` (variable,value,options,explanation,type)
         VALUES ('yuipath','http://yui.yahooapis.com/2.3.1/build','Insert the path to YUI libraries','','free')");
    print "Upgrade to $DBversion done (adding new system preference for controlling YUI path)\n";
    SetVersion ($DBversion);
} 
$DBversion = "3.00.00.024";
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
    $dbh->do("ALTER TABLE biblioitems CHANGE  itemtype itemtype VARCHAR(10)");
    print "Upgrade to $DBversion done (changing itemtype to (10))\n";
    SetVersion ($DBversion);
}

$DBversion = "3.00.00.025";
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
    $dbh->do("ALTER TABLE items ADD COLUMN itype VARCHAR(10)");
    $dbh->do("ALTER TABLE deleteditems ADD COLUMN itype VARCHAR(10) AFTER uri");
    if(C4::Context->preference('item-level_itypes')){
        $dbh->do('update items,biblioitems set items.itype=biblioitems.itemtype where items.biblionumber=biblioitems.biblionumber and itype is null');
    }
    print "Upgrade to $DBversion done (reintroduce items.itype - fill from itemtype)\n ";
    SetVersion ($DBversion);
}

$DBversion = "3.00.00.026";
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
    $dbh->do("INSERT INTO `systempreferences` (variable,value,options,explanation,type)
       VALUES ('HomeOrHoldingBranch','homebranch','homebranch|holdingbranch','With independent branches turned on this decides whether to check the items holdingbranch or homebranch at circulatilon','choice')");
    print "Upgrade to $DBversion done (adding new system preference for choosing whether homebranch or holdingbranch is checked in circulation)\n";
    SetVersion ($DBversion);
}

$DBversion = "3.00.00.027";
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
    $dbh->do("CREATE TABLE `marc_matchers` (
                `matcher_id` int(11) NOT NULL auto_increment,
                `code` varchar(10) NOT NULL default '',
                `description` varchar(255) NOT NULL default '',
                `record_type` varchar(10) NOT NULL default 'biblio',
                `threshold` int(11) NOT NULL default 0,
                PRIMARY KEY (`matcher_id`),
                KEY `code` (`code`),
                KEY `record_type` (`record_type`)
              ) ENGINE=InnoDB DEFAULT CHARSET=utf8");
    $dbh->do("CREATE TABLE `matchpoints` (
                `matcher_id` int(11) NOT NULL,
                `matchpoint_id` int(11) NOT NULL auto_increment,
                `search_index` varchar(30) NOT NULL default '',
                `score` int(11) NOT NULL default 0,
                PRIMARY KEY (`matchpoint_id`),
                CONSTRAINT `matchpoints_ifbk_1` FOREIGN KEY (`matcher_id`)
                           REFERENCES `marc_matchers` (`matcher_id`) ON DELETE CASCADE ON UPDATE CASCADE
              ) ENGINE=InnoDB DEFAULT CHARSET=utf8");
    $dbh->do("CREATE TABLE `matchpoint_components` (
                `matchpoint_id` int(11) NOT NULL,
                `matchpoint_component_id` int(11) NOT NULL auto_increment,
                sequence int(11) NOT NULL default 0,
                tag varchar(3) NOT NULL default '',
                subfields varchar(40) NOT NULL default '',
                offset int(4) NOT NULL default 0,
                length int(4) NOT NULL default 0,
                PRIMARY KEY (`matchpoint_component_id`),
                KEY `by_sequence` (`matchpoint_id`, `sequence`),
                CONSTRAINT `matchpoint_components_ifbk_1` FOREIGN KEY (`matchpoint_id`)
                           REFERENCES `matchpoints` (`matchpoint_id`) ON DELETE CASCADE ON UPDATE CASCADE
              ) ENGINE=InnoDB DEFAULT CHARSET=utf8");
    $dbh->do("CREATE TABLE `matchpoint_component_norms` (
                `matchpoint_component_id` int(11) NOT NULL,
                `sequence`  int(11) NOT NULL default 0,
                `norm_routine` varchar(50) NOT NULL default '',
                KEY `matchpoint_component_norms` (`matchpoint_component_id`, `sequence`),
                CONSTRAINT `matchpoint_component_norms_ifbk_1` FOREIGN KEY (`matchpoint_component_id`)
                           REFERENCES `matchpoint_components` (`matchpoint_component_id`) ON DELETE CASCADE ON UPDATE CASCADE
              ) ENGINE=InnoDB DEFAULT CHARSET=utf8");
    $dbh->do("CREATE TABLE `matcher_matchpoints` (
                `matcher_id` int(11) NOT NULL,
                `matchpoint_id` int(11) NOT NULL,
                CONSTRAINT `matcher_matchpoints_ifbk_1` FOREIGN KEY (`matcher_id`)
                           REFERENCES `marc_matchers` (`matcher_id`) ON DELETE CASCADE ON UPDATE CASCADE,
                CONSTRAINT `matcher_matchpoints_ifbk_2` FOREIGN KEY (`matchpoint_id`)
                           REFERENCES `matchpoints` (`matchpoint_id`) ON DELETE CASCADE ON UPDATE CASCADE
              ) ENGINE=InnoDB DEFAULT CHARSET=utf8");
    $dbh->do("CREATE TABLE `matchchecks` (
                `matcher_id` int(11) NOT NULL,
                `matchcheck_id` int(11) NOT NULL auto_increment,
                `source_matchpoint_id` int(11) NOT NULL,
                `target_matchpoint_id` int(11) NOT NULL,
                PRIMARY KEY (`matchcheck_id`),
                CONSTRAINT `matcher_matchchecks_ifbk_1` FOREIGN KEY (`matcher_id`)
                           REFERENCES `marc_matchers` (`matcher_id`) ON DELETE CASCADE ON UPDATE CASCADE,
                CONSTRAINT `matcher_matchchecks_ifbk_2` FOREIGN KEY (`source_matchpoint_id`)
                           REFERENCES `matchpoints` (`matchpoint_id`) ON DELETE CASCADE ON UPDATE CASCADE,
                CONSTRAINT `matcher_matchchecks_ifbk_3` FOREIGN KEY (`target_matchpoint_id`)
                           REFERENCES `matchpoints` (`matchpoint_id`) ON DELETE CASCADE ON UPDATE CASCADE
              ) ENGINE=InnoDB DEFAULT CHARSET=utf8");
    print "Upgrade to $DBversion done (added C4::Matcher serialization tables)\n ";
    SetVersion ($DBversion);
}

$DBversion = "3.00.00.028";
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
    $dbh->do("INSERT INTO `systempreferences` (variable,value,options,explanation,type)
       VALUES ('canreservefromotherbranches','1','','With Independent branches on, can a user from one library reserve an item from another library','YesNo')");
    print "Upgrade to $DBversion done (adding new system preference for changing reserve/holds behaviour with independent branches)\n";
    SetVersion ($DBversion);
}


$DBversion = "3.00.00.029";
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
    $dbh->do("ALTER TABLE `import_batches` ADD `matcher_id` int(11) NULL AFTER `import_batch_id`");
    print "Upgrade to $DBversion done (adding matcher_id to import_batches)\n";
    SetVersion ($DBversion);
}

$DBversion = "3.00.00.030";
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
    $dbh->do("
CREATE TABLE services_throttle (
  service_type varchar(10) NOT NULL default '',
  service_count varchar(45) default NULL,
  PRIMARY KEY  (service_type)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
");
    $dbh->do("INSERT INTO `systempreferences` (variable,value,options,explanation,type)
       VALUES ('FRBRizeEditions',0,'','If ON, Koha will query one or more ISBN web services for associated ISBNs and display an Editions tab on the details pages','YesNo')");
 $dbh->do("INSERT INTO `systempreferences` (variable,value,options,explanation,type)
       VALUES ('XISBN',0,'','Use with FRBRizeEditions. If ON, Koha will use the OCLC xISBN web service in the Editions tab on the detail pages. See: http://www.worldcat.org/affiliate/webservices/xisbn/app.jsp','YesNo')");
 $dbh->do("INSERT INTO `systempreferences` (variable,value,options,explanation,type)
       VALUES ('OCLCAffiliateID','','','Use with FRBRizeEditions and XISBN. You can sign up for an AffiliateID here: http://www.worldcat.org/wcpa/do/AffiliateUserServices?method=initSelfRegister','free')");
 $dbh->do("INSERT INTO `systempreferences` (variable,value,options,explanation,type)
       VALUES ('XISBNDailyLimit',499,'','The xISBN Web service is free for non-commercial use when usage does not exceed 500 requests per day','free')");
 $dbh->do("INSERT INTO `systempreferences` (variable,value,options,explanation,type)
       VALUES ('PINESISBN',0,'','Use with FRBRizeEditions. If ON, Koha will use PINES OISBN web service in the Editions tab on the detail pages.','YesNo')");
 $dbh->do("INSERT INTO `systempreferences` (variable,value,options,explanation,type)
       VALUES ('ThingISBN',0,'','Use with FRBRizeEditions. If ON, Koha will use the ThingISBN web service in the Editions tab on the detail pages.','YesNo')");
    print "Upgrade to $DBversion done (adding services throttle table and sysprefs for xISBN)\n";
    SetVersion ($DBversion);
}

$DBversion = "3.00.00.031";
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {

$dbh->do("INSERT INTO `systempreferences` (variable,value,explanation,options,type) VALUES('QueryStemming',1,'If ON, enables query stemming',NULL,'YesNo')");
$dbh->do("INSERT INTO `systempreferences` (variable,value,explanation,options,type) VALUES('QueryFuzzy',1,'If ON, enables fuzzy option for searches',NULL,'YesNo')");
$dbh->do("INSERT INTO `systempreferences` (variable,value,explanation,options,type) VALUES('QueryWeightFields',1,'If ON, enables field weighting',NULL,'YesNo')");
$dbh->do("INSERT INTO `systempreferences` (variable,value,explanation,options,type) VALUES('WebBasedSelfCheck',0,'If ON, enables the web-based self-check system',NULL,'YesNo')");
$dbh->do("INSERT INTO `systempreferences` (variable,value,explanation,options,type) VALUES('numSearchResults',20,'Specify the maximum number of results to display on a page of results',NULL,'free')");
$dbh->do("INSERT INTO `systempreferences` (variable,value,explanation,options,type) VALUES('OPACnumSearchResults',20,'Specify the maximum number of results to display on a page of results',NULL,'free')");
$dbh->do("INSERT INTO `systempreferences` (variable,value,explanation,options,type) VALUES('maxItemsInSearchResults',20,'Specify the maximum number of items to display for each result on a page of results',NULL,'free')");
$dbh->do("INSERT INTO `systempreferences` (variable,value,explanation,options,type) VALUES('defaultSortField',NULL,'Specify the default field used for sorting','relevance|popularity|call_number|pubdate|acqdate|title|author','Choice')");
$dbh->do("INSERT INTO `systempreferences` (variable,value,explanation,options,type) VALUES('defaultSortOrder',NULL,'Specify the default sort order','asc|dsc|az|za','Choice')");
$dbh->do("INSERT INTO `systempreferences` (variable,value,explanation,options,type) VALUES('OPACdefaultSortField',NULL,'Specify the default field used for sorting','relevance|popularity|call_number|pubdate|acqdate|title|author','Choice')");
$dbh->do("INSERT INTO `systempreferences` (variable,value,explanation,options,type) VALUES('OPACdefaultSortOrder',NULL,'Specify the default sort order','asc|dsc|za|az','Choice')");
$dbh->do("INSERT INTO `systempreferences` (variable,value,explanation,options,type) VALUES('staffClientBaseURL','','Specify the base URL of the staff client',NULL,'free')");
$dbh->do("INSERT INTO `systempreferences` (variable,value,explanation,options,type) VALUES('minPasswordLength',3,'Specify the minimum length of a patron/staff password',NULL,'free')");
$dbh->do("INSERT INTO `systempreferences` (variable,value,explanation,options,type) VALUES('noItemTypeImages',0,'If ON, disables item-type images',NULL,'YesNo')");
$dbh->do("INSERT INTO `systempreferences` (variable,value,explanation,options,type) VALUES('emailLibrarianWhenHoldIsPlaced',0,'If ON, emails the librarian whenever a hold is placed',NULL,'YesNo')");
$dbh->do("INSERT INTO `systempreferences` (variable,value,explanation,options,type) VALUES('holdCancelLength','','Specify how many days before a hold is canceled',NULL,'free')");
$dbh->do("INSERT INTO `systempreferences` (variable,value,explanation,options,type) VALUES('libraryAddress','','The address to use for printing receipts, overdues, etc. if different than physical address',NULL,'free')");
$dbh->do("INSERT INTO `systempreferences` (variable,value,explanation,options,type) VALUES('finesMode','test','Choose the fines mode, test or production','test|production','Choice')");
$dbh->do("INSERT INTO `systempreferences` (variable,value,explanation,options,type) VALUES('globalDueDate','','If set, allows a global static due date for all checkouts',NULL,'free')");
$dbh->do("INSERT INTO `systempreferences` (variable,value,explanation,options,type) VALUES('itemBarcodeInputFilter','','If set, allows specification of a item barcode input filter','cuecat','Choice')");
$dbh->do("INSERT INTO `systempreferences` (variable,value,explanation,options,type) VALUES('singleBranchMode',0,'Operate in Single-branch mode, hide branch selection in the OPAC',NULL,'YesNo')");
$dbh->do("INSERT INTO `systempreferences` (variable,value,explanation,options,type) VALUES('URLLinkText','','Text to display as the link anchor in the OPAC',NULL,'free')");
$dbh->do("INSERT INTO `systempreferences` (variable,value,explanation,options,type) VALUES('OPACSubscriptionDisplay','economical','Specify how to display subscription information in the OPAC','economical|off|full','Choice')");
$dbh->do("INSERT INTO `systempreferences` (variable,value,explanation,options,type) VALUES('OPACDisplayExtendedSubInfo',1,'If ON, extended subscription information is displayed in the OPAC',NULL,'YesNo')");
$dbh->do("INSERT INTO `systempreferences` (variable,value,explanation,options,type) VALUES('OPACViewOthersSuggestions',0,'If ON, allows all suggestions to be displayed in the OPAC',NULL,'YesNo')");
$dbh->do("INSERT INTO `systempreferences` (variable,value,explanation,options,type) VALUES('OPACURLOpenInNewWindow',0,'If ON, URLs in the OPAC open in a new window',NULL,'YesNo')");
$dbh->do("INSERT INTO `systempreferences` (variable,value,explanation,options,type) VALUES('OPACUserCSS',0,'Add CSS to be included in the OPAC',NULL,'free')");

    print "Upgrade to $DBversion done (adding additional system preference)\n";
    SetVersion ($DBversion);
}

$DBversion = "3.00.00.032";
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
    $dbh->do("UPDATE `marc_subfield_structure` SET `kohafield` = 'items.wthdrawn' WHERE `kohafield` = 'items.withdrawn'");
    print "Upgrade to $DBversion done (fixed MARC framework references to items.withdrawn)\n";
    SetVersion ($DBversion);
}

$DBversion = "3.00.00.033";
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
    $dbh->do("INSERT INTO `userflags` VALUES(17,'staffaccess','Modify login / permissions for staff users',0)");
    print "Upgrade to $DBversion done (Adding permissions flag for staff member access modification.  )\n";
    SetVersion ($DBversion);
}

$DBversion = "3.00.00.034";
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
    $dbh->do("ALTER TABLE `virtualshelves` ADD COLUMN `sortfield` VARCHAR(16) ");
    print "Upgrade to $DBversion done (Adding sortfield for Virtual Shelves.  )\n";
    SetVersion ($DBversion);
}

$DBversion = "3.00.00.035";
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
    $dbh->do("UPDATE marc_subfield_structure
              SET authorised_value = 'cn_source'
              WHERE kohafield IN ('items.cn_source', 'biblioitems.cn_source')
              AND (authorised_value is NULL OR authorised_value = '')");
    print "Upgrade to $DBversion done (MARC frameworks: make classification source a drop-down)\n";
    SetVersion ($DBversion);
}

$DBversion = "3.00.00.036";
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
    $dbh->do("INSERT INTO `systempreferences` (variable,value,explanation,options,type) VALUES('OPACItemsResultsDisplay','statuses','statuses : show only the status of items in result list. itemdisplay : show full location of items (branch+location+callnumber) as in staff interface','statuses|itemdetails','Choice');");
    print "Upgrade to $DBversion done (OPACItemsResultsDisplay systempreference added)\n";
    SetVersion ($DBversion);
}

$DBversion = "3.00.00.037";
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
    $dbh->do("ALTER TABLE `borrowers` ADD COLUMN `altcontactfirstname` varchar(255)");
    $dbh->do("ALTER TABLE `borrowers` ADD COLUMN `altcontactsurname` varchar(255)");
    $dbh->do("ALTER TABLE `borrowers` ADD COLUMN `altcontactaddress1` varchar(255)");
    $dbh->do("ALTER TABLE `borrowers` ADD COLUMN `altcontactaddress2` varchar(255)");
    $dbh->do("ALTER TABLE `borrowers` ADD COLUMN `altcontactaddress3` varchar(255)");
    $dbh->do("ALTER TABLE `borrowers` ADD COLUMN `altcontactzipcode` varchar(50)");
    $dbh->do("ALTER TABLE `borrowers` ADD COLUMN `altcontactphone` varchar(50)");
    print "Upgrade to $DBversion done (Adding Alternative Contact Person information to borrowers table)\n";
    SetVersion ($DBversion);
}

$DBversion = "3.00.00.038";
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
    $dbh->do("UPDATE `systempreferences` set explanation='Choose the fines mode, off, test (emails admin report) or production (accrue overdue fines).  Requires fines cron script' , options='off|test|production' where variable='finesMode'");
    $dbh->do("DELETE FROM `systempreferences` WHERE variable='hideBiblioNumber'");
    print "Upgrade to $DBversion done ('alter finesMode systempreference, remove superfluous syspref.')\n";
    SetVersion ($DBversion);
}

$DBversion = "3.00.00.039";
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
    $dbh->do("INSERT INTO `systempreferences` (variable,value,explanation,options,type) VALUES('uppercasesurnames',0,'If ON, surnames are converted to upper case in patron entry form',NULL,'YesNo')");
    $dbh->do("INSERT INTO `systempreferences` (variable,value,explanation,options,type) VALUES('CircControl','ItemHomeLibrary','Specify the agency that controls the circulation and fines policy','PickupLibrary|PatronLibrary|ItemHomeLibrary','Choice')");
    $dbh->do("INSERT INTO `systempreferences` (variable,value,explanation,options,type) VALUES('finesCalendar','noFinesWhenClosed','Specify whether to use the Calendar in calculating duedates and fines','ignoreCalendar|noFinesWhenClosed','Choice')");
    # $dbh->do("DELETE FROM `systempreferences` WHERE variable='HomeOrHoldingBranch'"); # Bug #2752
    print "Upgrade to $DBversion done ('add circ sysprefs CircControl, finesCalendar, and uppercasesurnames, and delete HomeOrHoldingBranch.')\n";
    SetVersion ($DBversion);
}

$DBversion = "3.00.00.040";
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
	$dbh->do("INSERT INTO `systempreferences` (variable,value,explanation,options,type) VALUES('previousIssuesDefaultSortOrder','asc','Specify the sort order of Previous Issues on the circulation page','asc|desc','Choice')");
	$dbh->do("INSERT INTO systempreferences (variable,value,explanation,options,type) VALUES('todaysIssuesDefaultSortOrder','desc','Specify the sort order of Todays Issues on the circulation page','asc|desc','Choice')");
	print "Upgrade to $DBversion done ('add circ sysprefs todaysIssuesDefaultSortOrder and previousIssuesDefaultSortOrder.')\n";
    SetVersion ($DBversion);
}


$DBversion = "3.00.00.041";
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
    # Strictly speaking it is not necessary to explicitly change
    # NULL values to 0, because the ALTER TABLE statement will do that.
    # However, setting them first avoids a warning.
    $dbh->do("UPDATE items SET notforloan = 0 WHERE notforloan IS NULL");
    $dbh->do("UPDATE items SET damaged = 0 WHERE damaged IS NULL");
    $dbh->do("UPDATE items SET itemlost = 0 WHERE itemlost IS NULL");
    $dbh->do("UPDATE items SET wthdrawn = 0 WHERE wthdrawn IS NULL");
    $dbh->do("ALTER TABLE items
                MODIFY notforloan tinyint(1) NOT NULL default 0,
                MODIFY damaged    tinyint(1) NOT NULL default 0,
                MODIFY itemlost   tinyint(1) NOT NULL default 0,
                MODIFY wthdrawn   tinyint(1) NOT NULL default 0");
    $dbh->do("UPDATE deleteditems SET notforloan = 0 WHERE notforloan IS NULL");
    $dbh->do("UPDATE deleteditems SET damaged = 0 WHERE damaged IS NULL");
    $dbh->do("UPDATE deleteditems SET itemlost = 0 WHERE itemlost IS NULL");
    $dbh->do("UPDATE deleteditems SET wthdrawn = 0 WHERE wthdrawn IS NULL");
    $dbh->do("ALTER TABLE deleteditems
                MODIFY notforloan tinyint(1) NOT NULL default 0,
                MODIFY damaged    tinyint(1) NOT NULL default 0,
                MODIFY itemlost   tinyint(1) NOT NULL default 0,
                MODIFY wthdrawn   tinyint(1) NOT NULL default 0");
	print "Upgrade to $DBversion done (disallow NULL in several item status columns)\n";
    SetVersion ($DBversion);
}

$DBversion = "3.00.00.042";
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
    $dbh->do("ALTER TABLE aqbooksellers CHANGE name name mediumtext NOT NULL");
	print "Upgrade to $DBversion done (disallow NULL in aqbooksellers.name; part of fix for bug 1251)\n";
    SetVersion ($DBversion);
}

$DBversion = "3.00.00.043";
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
    $dbh->do("ALTER TABLE `currency` ADD `symbol` varchar(5) default NULL AFTER currency, ADD `timestamp` timestamp NOT NULL default CURRENT_TIMESTAMP on update CURRENT_TIMESTAMP AFTER symbol");
	print "Upgrade to $DBversion done (currency table: add symbol and timestamp columns)\n";
    SetVersion ($DBversion);
}

$DBversion = "3.00.00.044";
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
    $dbh->do("ALTER TABLE deletedborrowers
  ADD `altcontactfirstname` varchar(255) default NULL,
  ADD `altcontactsurname` varchar(255) default NULL,
  ADD `altcontactaddress1` varchar(255) default NULL,
  ADD `altcontactaddress2` varchar(255) default NULL,
  ADD `altcontactaddress3` varchar(255) default NULL,
  ADD `altcontactzipcode` varchar(50) default NULL,
  ADD `altcontactphone` varchar(50) default NULL
  ");
  $dbh->do("INSERT INTO `systempreferences` (variable,value,explanation,options,type) VALUES
('OPACBaseURL',NULL,'Specify the Base URL of the OPAC, e.g., opac.mylibrary.com, the http:// will be added automatically by Koha.',NULL,'Free'),
('language','en','Set the default language in the staff client.',NULL,'Languages'),
('QueryAutoTruncate',1,'If ON, query truncation is enabled by default',NULL,'YesNo'),
('QueryRemoveStopwords',0,'If ON, stopwords listed in the Administration area will be removed from queries',NULL,'YesNo')
  ");
        print "Upgrade to $DBversion done (syncing deletedborrowers table with borrowers table)\n";
    SetVersion ($DBversion);
}

#-- http://www.w3.org/International/articles/language-tags/

#-- RFC4646
$DBversion = "3.00.00.045";
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
    $dbh->do("
CREATE TABLE language_subtag_registry (
        subtag varchar(25),
        type varchar(25), -- language-script-region-variant-extension-privateuse
        description varchar(25), -- only one of the possible descriptions for ease of reference, see language_descriptions for the complete list
        added date,
        KEY `subtag` (`subtag`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8");

#-- TODO: add suppress_scripts
#-- this maps three letter codes defined in iso639.2 back to their
#-- two letter equivilents in rfc4646 (LOC maintains iso639+)
 $dbh->do("CREATE TABLE language_rfc4646_to_iso639 (
        rfc4646_subtag varchar(25),
        iso639_2_code varchar(25),
        KEY `rfc4646_subtag` (`rfc4646_subtag`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8");

 $dbh->do("CREATE TABLE language_descriptions (
        subtag varchar(25),
        type varchar(25),
        lang varchar(25),
        description varchar(255),
        KEY `lang` (`lang`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8");

#-- bi-directional support, keyed by script subcode
 $dbh->do("CREATE TABLE language_script_bidi (
        rfc4646_subtag varchar(25), -- script subtag, Arab, Hebr, etc.
        bidi varchar(3), -- rtl ltr
        KEY `rfc4646_subtag` (`rfc4646_subtag`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8");

#-- BIDI Stuff, Arabic and Hebrew
 $dbh->do("INSERT INTO language_script_bidi(rfc4646_subtag,bidi)
VALUES( 'Arab', 'rtl')");
 $dbh->do("INSERT INTO language_script_bidi(rfc4646_subtag,bidi)
VALUES( 'Hebr', 'rtl')");

#-- TODO: need to map language subtags to script subtags for detection
#-- of bidi when script is not specified (like ar, he)
 $dbh->do("CREATE TABLE language_script_mapping (
        language_subtag varchar(25),
        script_subtag varchar(25),
        KEY `language_subtag` (`language_subtag`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8");

#-- Default mappings between script and language subcodes
 $dbh->do("INSERT INTO language_script_mapping(language_subtag,script_subtag)
VALUES( 'ar', 'Arab')");
 $dbh->do("INSERT INTO language_script_mapping(language_subtag,script_subtag)
VALUES( 'he', 'Hebr')");

        print "Upgrade to $DBversion done (adding language subtag registry and basic BiDi support NOTE: You should import the subtag registry SQL)\n";
    SetVersion ($DBversion);
}

$DBversion = "3.00.00.046";
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
    $dbh->do("ALTER TABLE `subscription` CHANGE `numberlength` `numberlength` int(11) default '0' , 
    		 CHANGE `weeklength` `weeklength` int(11) default '0'");
    $dbh->do("CREATE TABLE `serialitems` (`serialid` int(11) NOT NULL, `itemnumber` int(11) NOT NULL, UNIQUE KEY `serialididx` (`serialid`) ) ENGINE=InnoDB DEFAULT CHARSET=utf8");
    $dbh->do("INSERT INTO `serialitems` SELECT `serialid`,`itemnumber` from serial where NOT ISNULL(itemnumber) && itemnumber <> '' && itemnumber NOT LIKE '%,%'");
	print "Upgrade to $DBversion done (Add serialitems table to link serial issues to items. )\n";
    SetVersion ($DBversion);
}

$DBversion = "3.00.00.047";
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
    $dbh->do("INSERT INTO `systempreferences` (variable,value,explanation,options,type) VALUES('OpacRenewalAllowed',0,'If ON, users can renew their issues directly from their OPAC account',NULL,'YesNo');");
	print "Upgrade to $DBversion done ( Added OpacRenewalAllowed syspref )\n";
    SetVersion ($DBversion);
}

$DBversion = "3.00.00.048";
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
    $dbh->do("ALTER TABLE `items` ADD `more_subfields_xml` longtext default NULL AFTER `itype`");
	print "Upgrade to $DBversion done (added items.more_subfields_xml)\n";
    SetVersion ($DBversion);
}

$DBversion = "3.00.00.049";
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
	$dbh->do("ALTER TABLE `z3950servers` ADD `encoding` text default NULL AFTER type ");
	print "Upgrade to $DBversion done ( Added encoding field to z3950servers table )\n";
    SetVersion ($DBversion);
}

$DBversion = "3.00.00.050";
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
    $dbh->do("INSERT INTO `systempreferences` (variable,value,explanation,options,type) VALUES('OpacHighlightedWords','0','If Set, query matched terms are highlighted in OPAC',NULL,'YesNo');");
	print "Upgrade to $DBversion done ( Added OpacHighlightedWords syspref )\n";
    SetVersion ($DBversion);
}

$DBversion = "3.00.00.051";
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
    $dbh->do("UPDATE systempreferences SET explanation = 'Define the current theme for the OPAC interface.' WHERE variable = 'opacthemes';");
	print "Upgrade to $DBversion done ( Corrected opacthemes explanation. )\n";
    SetVersion ($DBversion);
}

$DBversion = "3.00.00.052";
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
    $dbh->do("ALTER TABLE `deleteditems` ADD `more_subfields_xml` LONGTEXT DEFAULT NULL AFTER `itype`");
	print "Upgrade to $DBversion done ( Adding missing column to deleteditems table. )\n";
    SetVersion ($DBversion);
}

$DBversion = "3.00.00.053"; 
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
    $dbh->do("CREATE TABLE `printers_profile` (
            `prof_id` int(4) NOT NULL auto_increment,
            `printername` varchar(40) NOT NULL,
            `tmpl_id` int(4) NOT NULL,
            `paper_bin` varchar(20) NOT NULL,
            `offset_horz` float default NULL,
            `offset_vert` float default NULL,
            `creep_horz` float default NULL,
            `creep_vert` float default NULL,
            `unit` char(20) NOT NULL default 'POINT',
            PRIMARY KEY  (`prof_id`),
            UNIQUE KEY `printername` (`printername`,`tmpl_id`,`paper_bin`),
            CONSTRAINT `printers_profile_pnfk_1` FOREIGN KEY (`tmpl_id`) REFERENCES `labels_templates` (`tmpl_id`) ON DELETE CASCADE ON UPDATE CASCADE
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8 ");
    $dbh->do("CREATE TABLE `labels_profile` (
            `tmpl_id` int(4) NOT NULL,
            `prof_id` int(4) NOT NULL,
            UNIQUE KEY `tmpl_id` (`tmpl_id`),
            UNIQUE KEY `prof_id` (`prof_id`)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8 ");
    print "Upgrade to $DBversion done ( Printer Profile tables added )\n";
    SetVersion ($DBversion);
}   

$DBversion = "3.00.00.054";
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
    $dbh->do("UPDATE systempreferences SET options = 'incremental|annual|hbyymmincr|OFF', explanation = 'Used to autogenerate a barcode: incremental will be of the form 1, 2, 3; annual of the form 2007-0001, 2007-0002; hbyymmincr of the form HB08010001 where HB = Home Branch' WHERE variable = 'autoBarcode';");
	print "Upgrade to $DBversion done ( Added another barcode autogeneration sequence to barcode.pl. )\n";
    SetVersion ($DBversion);
}

$DBversion = "3.00.00.055";
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
    $dbh->do("ALTER TABLE `zebraqueue` ADD KEY `zebraqueue_lookup` (`server`, `biblio_auth_number`, `operation`, `done`)");
	print "Upgrade to $DBversion done ( Added index on zebraqueue. )\n";
    SetVersion ($DBversion);
}
$DBversion = "3.00.00.056";
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
    if (C4::Context->preference("marcflavour") eq 'UNIMARC') {
        $dbh->do("INSERT INTO `marc_subfield_structure` (`tagfield`, `tagsubfield`, `liblibrarian`, `libopac`, `repeatable`, `mandatory`, `kohafield`, `tab`, `authorised_value` , `authtypecode`, `value_builder`, `isurl`, `hidden`, `frameworkcode`, `seealso`, `link`, `defaultvalue`) VALUES ('995', 'v', 'Note sur le N° de périodique','Note sur le N° de périodique', 0, 0, 'items.enumchron', 10, '', '', '', 0, 0, '', '', '', NULL) ");
    } else {
        $dbh->do("INSERT INTO `marc_subfield_structure` (`tagfield`, `tagsubfield`, `liblibrarian`, `libopac`, `repeatable`, `mandatory`, `kohafield`, `tab`, `authorised_value` , `authtypecode`, `value_builder`, `isurl`, `hidden`, `frameworkcode`, `seealso`, `link`, `defaultvalue`) VALUES ('952', 'h', 'Serial Enumeration / chronology','Serial Enumeration / chronology', 0, 0, 'items.enumchron', 10, '', '', '', 0, 0, '', '', '', NULL) ");
    }
    $dbh->do("ALTER TABLE `items` ADD `enumchron` VARCHAR(80) DEFAULT NULL;");
    print "Upgrade to $DBversion done ( Added item.enumchron column, and framework map to 952h )\n";
    SetVersion ($DBversion);
}
    
$DBversion = "3.00.00.057";
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
    $dbh->do("INSERT INTO `systempreferences` (variable,value,explanation,options,type) VALUES('OAI-PMH','0','if ON, OAI-PMH server is enabled',NULL,'YesNo');");
    $dbh->do("INSERT INTO `systempreferences` (variable,value,explanation,options,type) VALUES('OAI-PMH:archiveID','KOHA-OAI-TEST','OAI-PMH archive identification',NULL,'Free');");
    $dbh->do("INSERT INTO `systempreferences` (variable,value,explanation,options,type) VALUES('OAI-PMH:MaxCount','50','OAI-PMH maximum number of records by answer to ListRecords and ListIdentifiers queries',NULL,'Integer');");
    $dbh->do("INSERT INTO `systempreferences` (variable,value,explanation,options,type) VALUES('OAI-PMH:Set','SET,Experimental set\r\nSET:SUBSET,Experimental subset','OAI-PMH exported set, the set name is followed by a comma and a short description, one set by line',NULL,'Free');");
    $dbh->do("INSERT INTO `systempreferences` (variable,value,explanation,options,type) VALUES('OAI-PMH:Subset',\"itemtype='BOOK'\",'Restrict answer to matching raws of the biblioitems table (experimental)',NULL,'Free');");
    SetVersion ($DBversion);
}

$DBversion = "3.00.00.058";
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
    $dbh->do("ALTER TABLE `opac_news` 
                CHANGE `lang` `lang` VARCHAR( 25 ) 
                CHARACTER SET utf8 
                COLLATE utf8_general_ci 
                NOT NULL default ''");
	print "Upgrade to $DBversion done ( lang field in opac_news made longer )\n";
    SetVersion ($DBversion);
}

$DBversion = "3.00.00.059";
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {

    $dbh->do("CREATE TABLE IF NOT EXISTS `labels_templates` (
            `tmpl_id` int(4) NOT NULL auto_increment,
            `tmpl_code` char(100)  default '',
            `tmpl_desc` char(100) default '',
            `page_width` float default '0',
            `page_height` float default '0',
            `label_width` float default '0',
            `label_height` float default '0',
            `topmargin` float default '0',
            `leftmargin` float default '0',
            `cols` int(2) default '0',
            `rows` int(2) default '0',
            `colgap` float default '0',
            `rowgap` float default '0',
            `active` int(1) default NULL,
            `units` char(20)  default 'PX',
            `fontsize` int(4) NOT NULL default '3',
            PRIMARY KEY  (`tmpl_id`)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8;");
    $dbh->do("CREATE TABLE  IF NOT EXISTS `printers_profile` (
            `prof_id` int(4) NOT NULL auto_increment,
            `printername` varchar(40) NOT NULL,
            `tmpl_id` int(4) NOT NULL,
            `paper_bin` varchar(20) NOT NULL,
            `offset_horz` float default NULL,
            `offset_vert` float default NULL,
            `creep_horz` float default NULL,
            `creep_vert` float default NULL,
            `unit` char(20) NOT NULL default 'POINT',
            PRIMARY KEY  (`prof_id`),
            UNIQUE KEY `printername` (`printername`,`tmpl_id`,`paper_bin`),
            CONSTRAINT `printers_profile_pnfk_1` FOREIGN KEY (`tmpl_id`) REFERENCES `labels_templates` (`tmpl_id`) ON DELETE CASCADE ON UPDATE CASCADE
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8 ");
    print "Upgrade to $DBversion done ( Added labels_templates table if it did not exist. )\n";
    SetVersion ($DBversion);
}

$DBversion = "3.00.00.060";
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
    $dbh->do("CREATE TABLE IF NOT EXISTS `patronimage` (
            `cardnumber` varchar(16) NOT NULL,
            `mimetype` varchar(15) NOT NULL,
            `imagefile` mediumblob NOT NULL,
            PRIMARY KEY  (`cardnumber`),
            CONSTRAINT `patronimage_fk1` FOREIGN KEY (`cardnumber`) REFERENCES `borrowers` (`cardnumber`) ON DELETE CASCADE ON UPDATE CASCADE
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8;");
	print "Upgrade to $DBversion done ( Added patronimage table. )\n";
    SetVersion ($DBversion);
}

$DBversion = "3.00.00.061";
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
    $dbh->do("ALTER TABLE labels_templates ADD COLUMN font char(10) NOT NULL DEFAULT 'TR';");
	print "Upgrade to $DBversion done ( Added font column to labels_templates )\n";
    SetVersion ($DBversion);
}

$DBversion = "3.00.00.062";
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
    $dbh->do("CREATE TABLE `old_issues` (
                `borrowernumber` int(11) default NULL,
                `itemnumber` int(11) default NULL,
                `date_due` date default NULL,
                `branchcode` varchar(10) default NULL,
                `issuingbranch` varchar(18) default NULL,
                `returndate` date default NULL,
                `lastreneweddate` date default NULL,
                `return` varchar(4) default NULL,
                `renewals` tinyint(4) default NULL,
                `timestamp` timestamp NOT NULL default CURRENT_TIMESTAMP on update CURRENT_TIMESTAMP,
                `issuedate` date default NULL,
                KEY `old_issuesborridx` (`borrowernumber`),
                KEY `old_issuesitemidx` (`itemnumber`),
                KEY `old_bordate` (`borrowernumber`,`timestamp`),
                CONSTRAINT `old_issues_ibfk_1` FOREIGN KEY (`borrowernumber`) REFERENCES `borrowers` (`borrowernumber`) 
                    ON DELETE SET NULL ON UPDATE SET NULL,
                CONSTRAINT `old_issues_ibfk_2` FOREIGN KEY (`itemnumber`) REFERENCES `items` (`itemnumber`) 
                    ON DELETE SET NULL ON UPDATE SET NULL
                ) ENGINE=InnoDB DEFAULT CHARSET=utf8");
    $dbh->do("CREATE TABLE `old_reserves` (
                `borrowernumber` int(11) default NULL,
                `reservedate` date default NULL,
                `biblionumber` int(11) default NULL,
                `constrainttype` varchar(1) default NULL,
                `branchcode` varchar(10) default NULL,
                `notificationdate` date default NULL,
                `reminderdate` date default NULL,
                `cancellationdate` date default NULL,
                `reservenotes` mediumtext,
                `priority` smallint(6) default NULL,
                `found` varchar(1) default NULL,
                `timestamp` timestamp NOT NULL default CURRENT_TIMESTAMP on update CURRENT_TIMESTAMP,
                `itemnumber` int(11) default NULL,
                `waitingdate` date default NULL,
                KEY `old_reserves_borrowernumber` (`borrowernumber`),
                KEY `old_reserves_biblionumber` (`biblionumber`),
                KEY `old_reserves_itemnumber` (`itemnumber`),
                KEY `old_reserves_branchcode` (`branchcode`),
                CONSTRAINT `old_reserves_ibfk_1` FOREIGN KEY (`borrowernumber`) REFERENCES `borrowers` (`borrowernumber`) 
                    ON DELETE SET NULL ON UPDATE SET NULL,
                CONSTRAINT `old_reserves_ibfk_2` FOREIGN KEY (`biblionumber`) REFERENCES `biblio` (`biblionumber`) 
                    ON DELETE SET NULL ON UPDATE SET NULL,
                CONSTRAINT `old_reserves_ibfk_3` FOREIGN KEY (`itemnumber`) REFERENCES `items` (`itemnumber`) 
                    ON DELETE SET NULL ON UPDATE SET NULL
                ) ENGINE=InnoDB DEFAULT CHARSET=utf8");

    # move closed transactions to old_* tables
    $dbh->do("INSERT INTO old_issues SELECT * FROM issues WHERE returndate IS NOT NULL");
    $dbh->do("DELETE FROM issues WHERE returndate IS NOT NULL");
    $dbh->do("INSERT INTO old_reserves SELECT * FROM reserves WHERE cancellationdate IS NOT NULL OR found = 'F'");
    $dbh->do("DELETE FROM reserves WHERE cancellationdate IS NOT NULL OR found = 'F'");

	print "Upgrade to $DBversion done ( Added old_issues and old_reserves tables )\n";
    SetVersion ($DBversion);
}

$DBversion = "3.00.00.063";
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
    $dbh->do("ALTER TABLE deleteditems
                CHANGE COLUMN booksellerid booksellerid MEDIUMTEXT DEFAULT NULL,
                ADD COLUMN enumchron VARCHAR(80) DEFAULT NULL AFTER more_subfields_xml,
                ADD COLUMN copynumber SMALLINT(6) DEFAULT NULL AFTER enumchron;");
    $dbh->do("ALTER TABLE items
                CHANGE COLUMN booksellerid booksellerid MEDIUMTEXT,
                ADD COLUMN copynumber SMALLINT(6) DEFAULT NULL AFTER enumchron;");
	print "Upgrade to $DBversion done ( Changed items.booksellerid and deleteditems.booksellerid to MEDIUMTEXT and added missing items.copynumber and deleteditems.copynumber to fix Bug 1927)\n";
    SetVersion ($DBversion);
}

$DBversion = "3.00.00.064";
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
    $dbh->do("INSERT INTO `systempreferences` (variable,value,explanation,options,type) VALUES('AmazonLocale','US','Use to set the Locale of your Amazon.com Web Services','US|CA|DE|FR|JP|UK','Choice');");
    $dbh->do("INSERT INTO `systempreferences` (variable,value,explanation,options,type) VALUES('AWSAccessKeyID','','See:  http://aws.amazon.com','','free');");
    $dbh->do("DELETE FROM `systempreferences` WHERE variable='AmazonDevKey';");
    $dbh->do("DELETE FROM `systempreferences` WHERE variable='XISBNAmazonSimilarItems';");
    $dbh->do("DELETE FROM `systempreferences` WHERE variable='OPACXISBNAmazonSimilarItems';");
    print "Upgrade to $DBversion done (IMPORTANT: Upgrading to Amazon.com Associates Web Service 4.0 ) \n";
    SetVersion ($DBversion);
}

$DBversion = "3.00.00.065";
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
    $dbh->do("CREATE TABLE `patroncards` (
                `cardid` int(11) NOT NULL auto_increment,
                `batch_id` varchar(10) NOT NULL default '1',
                `borrowernumber` int(11) NOT NULL,
                `timestamp` timestamp NOT NULL default CURRENT_TIMESTAMP on update CURRENT_TIMESTAMP,
                PRIMARY KEY  (`cardid`),
                KEY `patroncards_ibfk_1` (`borrowernumber`),
                CONSTRAINT `patroncards_ibfk_1` FOREIGN KEY (`borrowernumber`) REFERENCES `borrowers` (`borrowernumber`) ON DELETE CASCADE ON UPDATE CASCADE
                ) ENGINE=InnoDB DEFAULT CHARSET=utf8;");
    print "Upgrade to $DBversion done (Adding patroncards table for patroncards generation feature. ) \n";
    SetVersion ($DBversion);
}

$DBversion = "3.00.00.066";
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
    $dbh->do("ALTER TABLE `virtualshelfcontents` MODIFY `dateadded` timestamp NOT NULL
DEFAULT CURRENT_TIMESTAMP on update CURRENT_TIMESTAMP;
");
    print "Upgrade to $DBversion done (fix for bug 1873: virtualshelfcontents dateadded column empty. ) \n";
    SetVersion ($DBversion);
}

$DBversion = "3.00.00.067";
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
    $dbh->do("UPDATE systempreferences SET explanation = 'Enable patron images for the Staff Client', type = 'YesNo' WHERE variable = 'patronimages'");
    print "Upgrade to $DBversion done (Updating patronimages syspref to reflect current kohastructure.sql. ) \n";
    SetVersion ($DBversion);
}

$DBversion = "3.00.00.068";
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
    $dbh->do("CREATE TABLE `permissions` (
                `module_bit` int(11) NOT NULL DEFAULT 0,
                `code` varchar(30) DEFAULT NULL,
                `description` varchar(255) DEFAULT NULL,
                PRIMARY KEY  (`module_bit`, `code`),
                CONSTRAINT `permissions_ibfk_1` FOREIGN KEY (`module_bit`) REFERENCES `userflags` (`bit`)
                    ON DELETE CASCADE ON UPDATE CASCADE
              ) ENGINE=InnoDB DEFAULT CHARSET=utf8");
    $dbh->do("CREATE TABLE `user_permissions` (
                `borrowernumber` int(11) NOT NULL DEFAULT 0,
                `module_bit` int(11) NOT NULL DEFAULT 0,
                `code` varchar(30) DEFAULT NULL,
                CONSTRAINT `user_permissions_ibfk_1` FOREIGN KEY (`borrowernumber`) REFERENCES `borrowers` (`borrowernumber`)
                    ON DELETE CASCADE ON UPDATE CASCADE,
                CONSTRAINT `user_permissions_ibfk_2` FOREIGN KEY (`module_bit`, `code`) 
                    REFERENCES `permissions` (`module_bit`, `code`)
                    ON DELETE CASCADE ON UPDATE CASCADE
              ) ENGINE=InnoDB DEFAULT CHARSET=utf8");

    $dbh->do("INSERT INTO permissions (module_bit, code, description) VALUES
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
    (13, 'schedule_tasks', 'Schedule tasks to run')");
        
    $dbh->do("INSERT INTO `systempreferences` (variable,value,explanation,options,type) VALUES('GranularPermissions','0','Use detailed staff user permissions',NULL,'YesNo')");

    print "Upgrade to $DBversion done (adding permissions and user_permissions tables and GranularPermissions syspref) \n";
    SetVersion ($DBversion);
}
$DBversion = "3.00.00.069";
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
    $dbh->do("ALTER TABLE labels_conf CHANGE COLUMN class classification int(1) DEFAULT NULL;");
	print "Upgrade to $DBversion done ( Correcting columname in labels_conf )\n";
    SetVersion ($DBversion);
}

$DBversion = "3.00.00.070";
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
    $sth = $dbh->prepare("SELECT value FROM systempreferences WHERE variable='yuipath'");
    $sth->execute;
    my ($value) = $sth->fetchrow;
    $value =~ s/2.3.1/2.5.1/;
    $dbh->do("UPDATE systempreferences SET value='$value' WHERE variable='yuipath';");
	print "Update yuipath syspref to 2.5.1 if necessary\n";
    SetVersion ($DBversion);
}

$DBversion = "3.00.00.071";
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
    $dbh->do(" ALTER TABLE `subscription` ADD `serialsadditems` TINYINT( 1 ) NOT NULL DEFAULT '0';");
    # fill the new field with the previous systempreference value, then drop the syspref
    my $sth = $dbh->prepare("SELECT value FROM systempreferences WHERE variable='serialsadditems'");
    $sth->execute;
    my ($serialsadditems) = $sth->fetchrow();
    $dbh->do("UPDATE subscription SET serialsadditems=$serialsadditems");
    $dbh->do("DELETE FROM systempreferences WHERE variable='serialsadditems'");
    print "Upgrade to $DBversion done ( moving serialsadditems from syspref to subscription )\n";
    SetVersion ($DBversion);
}

$DBversion = "3.00.00.072";
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
    $dbh->do("ALTER TABLE labels_conf ADD COLUMN formatstring mediumtext DEFAULT NULL AFTER printingtype");
	print "Upgrade to $DBversion done ( Adding format string to labels generator. )\n";
    SetVersion ($DBversion);
}

$DBversion = "3.00.00.073";
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
	$dbh->do("DROP TABLE IF EXISTS `tags_all`;");
	$dbh->do(q#
	CREATE TABLE `tags_all` (
	  `tag_id`         int(11) NOT NULL auto_increment,
	  `borrowernumber` int(11) NOT NULL,
	  `biblionumber`   int(11) NOT NULL,
	  `term`      varchar(255) NOT NULL,
	  `language`       int(4) default NULL,
	  `date_created` datetime  NOT NULL,
	  PRIMARY KEY  (`tag_id`),
	  KEY `tags_borrowers_fk_1` (`borrowernumber`),
	  KEY `tags_biblionumber_fk_1` (`biblionumber`),
	  CONSTRAINT `tags_borrowers_fk_1` FOREIGN KEY (`borrowernumber`)
		REFERENCES `borrowers` (`borrowernumber`) ON DELETE CASCADE ON UPDATE CASCADE,
	  CONSTRAINT `tags_biblionumber_fk_1` FOREIGN KEY (`biblionumber`)
		REFERENCES `biblio`     (`biblionumber`)  ON DELETE CASCADE ON UPDATE CASCADE
	) ENGINE=InnoDB DEFAULT CHARSET=utf8;
	#);
	$dbh->do("DROP TABLE IF EXISTS `tags_approval`;");
	$dbh->do(q#
	CREATE TABLE `tags_approval` (
	  `term`   varchar(255) NOT NULL,
	  `approved`     int(1) NOT NULL default '0',
	  `date_approved` datetime       default NULL,
	  `approved_by` int(11)          default NULL,
	  `weight_total` int(9) NOT NULL default '1',
	  PRIMARY KEY  (`term`),
	  KEY `tags_approval_borrowers_fk_1` (`approved_by`),
	  CONSTRAINT `tags_approval_borrowers_fk_1` FOREIGN KEY (`approved_by`)
		REFERENCES `borrowers` (`borrowernumber`) ON DELETE CASCADE ON UPDATE CASCADE
	) ENGINE=InnoDB DEFAULT CHARSET=utf8;
	#);
	$dbh->do("DROP TABLE IF EXISTS `tags_index`;");
	$dbh->do(q#
	CREATE TABLE `tags_index` (
	  `term`    varchar(255) NOT NULL,
	  `biblionumber` int(11) NOT NULL,
	  `weight`        int(9) NOT NULL default '1',
	  PRIMARY KEY  (`term`,`biblionumber`),
	  KEY `tags_index_biblionumber_fk_1` (`biblionumber`),
	  CONSTRAINT `tags_index_term_fk_1` FOREIGN KEY (`term`)
		REFERENCES `tags_approval` (`term`)  ON DELETE CASCADE ON UPDATE CASCADE,
	  CONSTRAINT `tags_index_biblionumber_fk_1` FOREIGN KEY (`biblionumber`)
		REFERENCES `biblio` (`biblionumber`) ON DELETE CASCADE ON UPDATE CASCADE
	) ENGINE=InnoDB DEFAULT CHARSET=utf8;
	#);
	$dbh->do(q#
	INSERT INTO `systempreferences` VALUES
		('BakerTaylorBookstoreURL','','','URL template for \"My Libary Bookstore\" links, to which the \"key\" value is appended, and \"https://\" is prepended.  It should include your hostname and \"Parent Number\".  Make this variable empty to turn MLB links off.  Example: ocls.mylibrarybookstore.com/MLB/actions/searchHandler.do?nextPage=bookDetails&parentNum=10923&key=',''),
		('BakerTaylorEnabled','0','','Enable or disable all Baker & Taylor features.','YesNo'),
		('BakerTaylorPassword','','','Baker & Taylor Password for Content Cafe (external content)','Textarea'),
		('BakerTaylorUsername','','','Baker & Taylor Username for Content Cafe (external content)','Textarea'),
		('TagsEnabled','1','','Enables or disables all tagging features.  This is the main switch for tags.','YesNo'),
		('TagsExternalDictionary',NULL,'','Path on server to local ispell executable, used to set $Lingua::Ispell::path  This dictionary is used as a \"whitelist\" of pre-allowed tags.',''),
		('TagsInputOnDetail','1','','Allow users to input tags from the detail page.',         'YesNo'),
		('TagsInputOnList',  '0','','Allow users to input tags from the search results list.', 'YesNo'),
		('TagsModeration',  NULL,'','Require tags from patrons to be approved before becoming visible.','YesNo'),
		('TagsShowOnDetail','10','','Number of tags to display on detail page.  0 is off.',        'Integer'),
		('TagsShowOnList',   '6','','Number of tags to display on search results list.  0 is off.','Integer')
	#);
	print "Upgrade to $DBversion done (Baker/Taylor,Tags: sysprefs and tables (tags_all, tags_index, tags_approval)) \n";
	SetVersion ($DBversion);
}

$DBversion = "3.00.00.074";
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
    $dbh->do( q(update itemtypes set imageurl = concat( 'npl/', imageurl )
                  where imageurl not like 'http%'
                    and imageurl is not NULL
                    and imageurl != '') );
    print "Upgrade to $DBversion done (updating imagetype.imageurls to reflect new icon locations.)\n";
    SetVersion ($DBversion);
}

$DBversion = "3.00.00.075";
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
    $dbh->do( q(alter table authorised_values add imageurl varchar(200) default NULL) );
    print "Upgrade to $DBversion done (adding imageurl field to authorised_values table)\n";
    SetVersion ($DBversion);
}

$DBversion = "3.00.00.076";
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
    $dbh->do("ALTER TABLE import_batches
              ADD COLUMN nomatch_action enum('create_new', 'ignore') NOT NULL default 'create_new' AFTER overlay_action");
    $dbh->do("ALTER TABLE import_batches
              ADD COLUMN item_action enum('always_add', 'add_only_for_matches', 'add_only_for_new', 'ignore') 
                  NOT NULL default 'always_add' AFTER nomatch_action");
    $dbh->do("ALTER TABLE import_batches
              MODIFY overlay_action  enum('replace', 'create_new', 'use_template', 'ignore')
                  NOT NULL default 'create_new'");
    $dbh->do("ALTER TABLE import_records
              MODIFY status  enum('error', 'staged', 'imported', 'reverted', 'items_reverted', 
                                  'ignored') NOT NULL default 'staged'");
    $dbh->do("ALTER TABLE import_items
              MODIFY status enum('error', 'staged', 'imported', 'reverted', 'ignored') NOT NULL default 'staged'");

	print "Upgrade to $DBversion done (changes to import_batches and import_records)\n";
	SetVersion ($DBversion);
}

$DBversion = "3.00.00.077";
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
    # drop these tables only if they exist and none of them are empty
    # these tables are not defined in the packaged 2.2.9, but since it is believed
    # that at least one library may be using them in a post-2.2.9 but pre-3.0 Koha,
    # some care is taken.
    my ($print_error) = $dbh->{PrintError};
    $dbh->{PrintError} = 0;
    my ($raise_error) = $dbh->{RaiseError};
    $dbh->{RaiseError} = 1;
    
    my $count = 0;
    my $do_drop = 1;
    eval { $count = $dbh->do("SELECT 1 FROM categorytable"); };
    if ($count > 0) {
        $do_drop = 0;
    }
    eval { $count = $dbh->do("SELECT 1 FROM mediatypetable"); };
    if ($count > 0) {
        $do_drop = 0;
    }
    eval { $count = $dbh->do("SELECT 1 FROM subcategorytable"); };
    if ($count > 0) {
        $do_drop = 0;
    }

    if ($do_drop) {
        $dbh->do("DROP TABLE IF EXISTS `categorytable`");
        $dbh->do("DROP TABLE IF EXISTS `mediatypetable`");
        $dbh->do("DROP TABLE IF EXISTS `subcategorytable`");
    }

    $dbh->{PrintError} = $print_error;
    $dbh->{RaiseError} = $raise_error;
	print "Upgrade to $DBversion done (drop categorytable, subcategorytable, and mediatypetable)\n";
	SetVersion ($DBversion);
}

$DBversion = "3.00.00.078";
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
    my ($print_error) = $dbh->{PrintError};
    $dbh->{PrintError} = 0;
    
    unless ($dbh->do("SELECT 1 FROM browser")) {
        $dbh->{PrintError} = $print_error;
        $dbh->do("CREATE TABLE `browser` (
                    `level` int(11) NOT NULL,
                    `classification` varchar(20) NOT NULL,
                    `description` varchar(255) NOT NULL,
                    `number` bigint(20) NOT NULL,
                    `endnode` tinyint(4) NOT NULL
                  ) ENGINE=InnoDB DEFAULT CHARSET=utf8");
    }
    $dbh->{PrintError} = $print_error;
	print "Upgrade to $DBversion done (add browser table if not already present)\n";
	SetVersion ($DBversion);
}

$DBversion = "3.00.00.079";
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
 my ($print_error) = $dbh->{PrintError};
    $dbh->{PrintError} = 0;

    $dbh->do("INSERT INTO `systempreferences` (variable, value,options,type, explanation)VALUES
        ('AddPatronLists','categorycode','categorycode|category_type','Choice','Allow user to choose what list to pick up from when adding patrons')");
    print "Upgrade to $DBversion done (add browser table if not already present)\n";
	SetVersion ($DBversion);
}

$DBversion = "3.00.00.080";
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
    $dbh->do("ALTER TABLE subscription CHANGE monthlength monthlength int(11) default '0'");
    $dbh->do("ALTER TABLE deleteditems MODIFY marc LONGBLOB AFTER copynumber");
    $dbh->do("ALTER TABLE aqbooksellers CHANGE name name mediumtext NOT NULL");
	print "Upgrade to $DBversion done (catch up on DB schema changes since alpha and beta)\n";
	SetVersion ($DBversion);
}

$DBversion = "3.00.00.081";
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
    $dbh->do("CREATE TABLE `borrower_attribute_types` (
                `code` varchar(10) NOT NULL,
                `description` varchar(255) NOT NULL,
                `repeatable` tinyint(1) NOT NULL default 0,
                `unique_id` tinyint(1) NOT NULL default 0,
                `opac_display` tinyint(1) NOT NULL default 0,
                `password_allowed` tinyint(1) NOT NULL default 0,
                `staff_searchable` tinyint(1) NOT NULL default 0,
                `authorised_value_category` varchar(10) default NULL,
                PRIMARY KEY  (`code`)
              ) ENGINE=InnoDB DEFAULT CHARSET=utf8");
    $dbh->do("CREATE TABLE `borrower_attributes` (
                `borrowernumber` int(11) NOT NULL,
                `code` varchar(10) NOT NULL,
                `attribute` varchar(30) default NULL,
                `password` varchar(30) default NULL,
                KEY `borrowernumber` (`borrowernumber`),
                KEY `code_attribute` (`code`, `attribute`),
                CONSTRAINT `borrower_attributes_ibfk_1` FOREIGN KEY (`borrowernumber`) REFERENCES `borrowers` (`borrowernumber`)
                    ON DELETE CASCADE ON UPDATE CASCADE,
                CONSTRAINT `borrower_attributes_ibfk_2` FOREIGN KEY (`code`) REFERENCES `borrower_attribute_types` (`code`)
                    ON DELETE CASCADE ON UPDATE CASCADE
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8");
    $dbh->do("INSERT INTO `systempreferences` (variable,value,explanation,options,type) VALUES('ExtendedPatronAttributes','0','Use extended patron IDs and attributes',NULL,'YesNo')");
    print "Upgrade to $DBversion done (added borrower_attributes and  borrower_attribute_types)\n";
 SetVersion ($DBversion);
}

$DBversion = "3.00.00.082";
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
    $dbh->do( q(alter table accountlines add column lastincrement decimal(28,6) default NULL) );
    print "Upgrade to $DBversion done (adding lastincrement column to accountlines table)\n";
    SetVersion ($DBversion);
}

$DBversion = "3.00.00.083";                                                                                                        
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {                                                             
    $dbh->do( qq(UPDATE systempreferences SET value='local' where variable='yuipath' and value like "%/intranet-tmpl/prog/%"));    
    print "Upgrade to $DBversion done (Changing yuipath behaviour in managing a local value)\n";                                   
    SetVersion ($DBversion);                                                                                                       
}
$DBversion = "3.00.00.084";
    if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
    $dbh->do("INSERT INTO systempreferences (variable,value,explanation,options,type) VALUES('RenewSerialAddsSuggestion','0','if ON, adds a new suggestion at serial subscription renewal',NULL,'YesNo')");
    $dbh->do("INSERT INTO systempreferences (variable,value,explanation,options,type) VALUES('GoogleJackets','0','if ON, displays jacket covers from Google Books API',NULL,'YesNo')");
    print "Upgrade to $DBversion done (add new sysprefs)\n";
    SetVersion ($DBversion);
}                                             

$DBversion = "3.00.00.085";
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
    if (C4::Context->preference("marcflavour") eq 'MARC21') {
        $dbh->do("UPDATE marc_subfield_structure SET tab = 0 WHERE tab =  9 AND tagfield = '037'");
        $dbh->do("UPDATE marc_subfield_structure SET tab = 1 WHERE tab =  6 AND tagfield in ('100', '110', '111', '130')");
        $dbh->do("UPDATE marc_subfield_structure SET tab = 2 WHERE tab =  6 AND tagfield in ('240', '243')");
        $dbh->do("UPDATE marc_subfield_structure SET tab = 4 WHERE tab =  6 AND tagfield in ('400', '410', '411', '440')");
        $dbh->do("UPDATE marc_subfield_structure SET tab = 5 WHERE tab =  9 AND tagfield = '584'");
        $dbh->do("UPDATE marc_subfield_structure SET tab = 7 WHERE tab = -6 AND tagfield = '760'");
    }
    print "Upgrade to $DBversion done (move editing tab of various MARC21 subfields)\n";
    SetVersion ($DBversion);
}

$DBversion = "3.00.00.086";
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
	$dbh->do(
	"CREATE TABLE `tmp_holdsqueue` (
  	`biblionumber` int(11) default NULL,
  	`itemnumber` int(11) default NULL,
  	`barcode` varchar(20) default NULL,
  	`surname` mediumtext NOT NULL,
  	`firstname` text,
  	`phone` text,
  	`borrowernumber` int(11) NOT NULL,
  	`cardnumber` varchar(16) default NULL,
  	`reservedate` date default NULL,
  	`title` mediumtext,
  	`itemcallnumber` varchar(30) default NULL,
  	`holdingbranch` varchar(10) default NULL,
  	`pickbranch` varchar(10) default NULL,
  	`notes` text
	) ENGINE=InnoDB DEFAULT CHARSET=utf8");

	$dbh->do("INSERT INTO systempreferences (variable,value,explanation,options,type) VALUES('RandomizeHoldsQueueWeight','0','if ON, the holds queue in circulation will be randomized, either based on all location codes, or by the location codes specified in StaticHoldsQueueWeight',NULL,'YesNo')");
	$dbh->do("INSERT INTO systempreferences (variable,value,explanation,options,type) VALUES('StaticHoldsQueueWeight','0','Specify a list of library location codes separated by commas -- the list of codes will be traversed and weighted with first values given higher weight for holds fulfillment -- alternatively, if RandomizeHoldsQueueWeight is set, the list will be randomly selective',NULL,'TextArea')");

	print "Upgrade to $DBversion done (Table structure for table `tmp_holdsqueue`)\n";
	SetVersion ($DBversion);
}

$DBversion = "3.00.00.087";
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
    $dbh->do("INSERT INTO `systempreferences` VALUES ('AutoEmailOpacUser','0','','Sends notification emails containing new account details to patrons - when account is created.','YesNo')" );
    $dbh->do("INSERT INTO `systempreferences` VALUES ('AutoEmailPrimaryAddress','OFF','email|emailpro|B_email|cardnumber|OFF','Defines the default email address where Account Details emails are sent.','Choice')");
    print "Upgrade to $DBversion done (added 2 new 'AutoEmailOpacUser' sysprefs)\n";
    SetVersion ($DBversion);
}

$DBversion = "3.00.00.088";
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
	$dbh->do("INSERT INTO `systempreferences` (variable,value,options,explanation,type) VALUES ('OPACShelfBrowser','1','','Enable/disable Shelf Browser on item details page','YesNo')");
	$dbh->do("INSERT INTO `systempreferences` (variable,value,options,explanation,type) VALUES ('OPACItemHolds','1','Allow OPAC users to place hold on specific items. If OFF, users can only request next available copy.','','YesNo')");
	$dbh->do("INSERT INTO `systempreferences` (variable,value,options,explanation,type) VALUES ('XSLTDetailsDisplay','0','','Enable XSL stylesheet control over details page display on OPAC WARNING: MARC21 Only','YesNo')");
	$dbh->do("INSERT INTO `systempreferences` (variable,value,options,explanation,type) VALUES ('XSLTResultsDisplay','0','','Enable XSL stylesheet control over results page display on OPAC WARNING: MARC21 Only','YesNo')");
	print "Upgrade to $DBversion done (added 2 new 'AutoEmailOpacUser' sysprefs)\n";
    SetVersion ($DBversion);
}

$DBversion = "3.00.00.089";
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
	$dbh->do("INSERT INTO `systempreferences` (variable,value,options,explanation,type) VALUES('AdvancedSearchTypes','itemtypes','itemtypes|ccode','Select which set of fields comprise the Type limit in the advanced search','Choice')");
	print "Upgrade to $DBversion done (added new AdvancedSearchTypes syspref)\n";
    SetVersion ($DBversion);
}

$DBversion = "3.00.00.090";
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
    $dbh->do("
        CREATE TABLE `branch_borrower_circ_rules` (
          `branchcode` VARCHAR(10) NOT NULL,
          `categorycode` VARCHAR(10) NOT NULL,
          `maxissueqty` int(4) default NULL,
          PRIMARY KEY (`categorycode`, `branchcode`),
          CONSTRAINT `branch_borrower_circ_rules_ibfk_1` FOREIGN KEY (`categorycode`) REFERENCES `categories` (`categorycode`)
            ON DELETE CASCADE ON UPDATE CASCADE,
          CONSTRAINT `branch_borrower_circ_rules_ibfk_2` FOREIGN KEY (`branchcode`) REFERENCES `branches` (`branchcode`)
            ON DELETE CASCADE ON UPDATE CASCADE
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8
    "); 
    $dbh->do("
        CREATE TABLE `default_borrower_circ_rules` (
          `categorycode` VARCHAR(10) NOT NULL,
          `maxissueqty` int(4) default NULL,
          PRIMARY KEY (`categorycode`),
          CONSTRAINT `borrower_borrower_circ_rules_ibfk_1` FOREIGN KEY (`categorycode`) REFERENCES `categories` (`categorycode`)
            ON DELETE CASCADE ON UPDATE CASCADE
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8
    "); 
    $dbh->do("
        CREATE TABLE `default_branch_circ_rules` (
          `branchcode` VARCHAR(10) NOT NULL,
          `maxissueqty` int(4) default NULL,
          PRIMARY KEY (`branchcode`),
          CONSTRAINT `default_branch_circ_rules_ibfk_1` FOREIGN KEY (`branchcode`) REFERENCES `branches` (`branchcode`)
            ON DELETE CASCADE ON UPDATE CASCADE
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8
    "); 
    $dbh->do("
        CREATE TABLE `default_circ_rules` (
            `singleton` enum('singleton') NOT NULL default 'singleton',
            `maxissueqty` int(4) default NULL,
            PRIMARY KEY (`singleton`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8
    ");
    print "Upgrade to $DBversion done (added several circ rules tables)\n";
    SetVersion ($DBversion);
}


$DBversion = "3.00.00.091";
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
    $dbh->do(<<'END_SQL');
ALTER TABLE borrowers
ADD `smsalertnumber` varchar(50) default NULL
END_SQL

    $dbh->do(<<'END_SQL');
CREATE TABLE `message_attributes` (
  `message_attribute_id` int(11) NOT NULL auto_increment,
  `message_name` varchar(20) NOT NULL default '',
  `takes_days` tinyint(1) NOT NULL default '0',
  PRIMARY KEY  (`message_attribute_id`),
  UNIQUE KEY `message_name` (`message_name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8
END_SQL

    $dbh->do(<<'END_SQL');
CREATE TABLE `message_transport_types` (
  `message_transport_type` varchar(20) NOT NULL,
  PRIMARY KEY  (`message_transport_type`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
END_SQL

    $dbh->do(<<'END_SQL');
CREATE TABLE `message_transports` (
  `message_attribute_id` int(11) NOT NULL,
  `message_transport_type` varchar(20) NOT NULL,
  `is_digest` tinyint(1) NOT NULL default '0',
  `letter_module` varchar(20) NOT NULL default '',
  `letter_code` varchar(20) NOT NULL default '',
  PRIMARY KEY  (`message_attribute_id`,`message_transport_type`,`is_digest`),
  KEY `message_transport_type` (`message_transport_type`),
  KEY `letter_module` (`letter_module`,`letter_code`),
  CONSTRAINT `message_transports_ibfk_1` FOREIGN KEY (`message_attribute_id`) REFERENCES `message_attributes` (`message_attribute_id`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `message_transports_ibfk_2` FOREIGN KEY (`message_transport_type`) REFERENCES `message_transport_types` (`message_transport_type`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `message_transports_ibfk_3` FOREIGN KEY (`letter_module`, `letter_code`) REFERENCES `letter` (`module`, `code`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8
END_SQL

    $dbh->do(<<'END_SQL');
CREATE TABLE `borrower_message_preferences` (
  `borrower_message_preference_id` int(11) NOT NULL auto_increment,
  `borrowernumber` int(11) NOT NULL default '0',
  `message_attribute_id` int(11) default '0',
  `days_in_advance` int(11) default '0',
  `wants_digets` tinyint(1) NOT NULL default '0',
  PRIMARY KEY  (`borrower_message_preference_id`),
  KEY `borrowernumber` (`borrowernumber`),
  KEY `message_attribute_id` (`message_attribute_id`),
  CONSTRAINT `borrower_message_preferences_ibfk_1` FOREIGN KEY (`borrowernumber`) REFERENCES `borrowers` (`borrowernumber`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `borrower_message_preferences_ibfk_2` FOREIGN KEY (`message_attribute_id`) REFERENCES `message_attributes` (`message_attribute_id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8
END_SQL

    $dbh->do(<<'END_SQL');
CREATE TABLE `borrower_message_transport_preferences` (
  `borrower_message_preference_id` int(11) NOT NULL default '0',
  `message_transport_type` varchar(20) NOT NULL default '0',
  PRIMARY KEY  (`borrower_message_preference_id`,`message_transport_type`),
  KEY `message_transport_type` (`message_transport_type`),
  CONSTRAINT `borrower_message_transport_preferences_ibfk_1` FOREIGN KEY (`borrower_message_preference_id`) REFERENCES `borrower_message_preferences` (`borrower_message_preference_id`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `borrower_message_transport_preferences_ibfk_2` FOREIGN KEY (`message_transport_type`) REFERENCES `message_transport_types` (`message_transport_type`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8
END_SQL

    $dbh->do(<<'END_SQL');
CREATE TABLE `message_queue` (
  `message_id` int(11) NOT NULL auto_increment,
  `borrowernumber` int(11) NOT NULL,
  `subject` text,
  `content` text,
  `message_transport_type` varchar(20) NOT NULL,
  `status` enum('sent','pending','failed','deleted') NOT NULL default 'pending',
  `time_queued` timestamp NOT NULL default CURRENT_TIMESTAMP on update CURRENT_TIMESTAMP,
  KEY `message_id` (`message_id`),
  KEY `borrowernumber` (`borrowernumber`),
  KEY `message_transport_type` (`message_transport_type`),
  CONSTRAINT `messageq_ibfk_1` FOREIGN KEY (`borrowernumber`) REFERENCES `borrowers` (`borrowernumber`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `messageq_ibfk_2` FOREIGN KEY (`message_transport_type`) REFERENCES `message_transport_types` (`message_transport_type`) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8
END_SQL

    $dbh->do(<<'END_SQL');
INSERT INTO `systempreferences`
  (variable,value,explanation,options,type)
VALUES
('EnhancedMessagingPreferences',0,'If ON, allows patrons to select to receive additional messages about items due or nearly due.','','YesNo')
END_SQL

    $dbh->do( <<'END_SQL');
INSERT INTO `letter`
(module, code, name, title, content)
VALUES
('circulation','DUE','Item Due Reminder','Item Due Reminder','Dear <<borrowers.firstname>> <<borrowers.surname>>,\r\n\r\nThe following item is now due:\r\n\r\n<<biblio.title>> by <<biblio.author>>'),
('circulation','DUEDGST','Item Due Reminder (Digest)','Item Due Reminder','You have <<count>> items due'),
('circulation','PREDUE','Advance Notice of Item Due','Advance Notice of Item Due','Dear <<borrowers.firstname>> <<borrowers.surname>>,\r\n\r\nThe following item will be due soon:\r\n\r\n<<biblio.title>> by <<biblio.author>>'),
('circulation','PREDUEDGST','Advance Notice of Item Due (Digest)','Advance Notice of Item Due','You have <<count>> items due soon'),
('circulation','EVENT','Upcoming Library Event','Upcoming Library Event','Dear <<borrowers.firstname>> <<borrowers.surname>>,\r\n\r\nThis is a reminder of an upcoming library event in which you have expressed interest.');
END_SQL

    my @sql_scripts = ( 
        'installer/data/mysql/en/mandatory/message_transport_types.sql',
        'installer/data/mysql/en/optional/sample_notices_message_attributes.sql',
        'installer/data/mysql/en/optional/sample_notices_message_transports.sql',
    );

    my $installer = C4::Installer->new();
    foreach my $script ( @sql_scripts ) {
        my $full_path = $installer->get_file_path_from_name($script);
        my $error = $installer->load_sql($full_path);
        warn $error if $error;
    }

    print "Upgrade to $DBversion done (Table structure for table `message_queue`, `message_transport_types`, `message_attributes`, `message_transports`, `borrower_message_preferences`, and `borrower_message_transport_preferences`.  Alter `borrowers` table,\n";
    SetVersion ($DBversion);
}

$DBversion = "3.00.00.092";
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
    $dbh->do("INSERT INTO `systempreferences` (variable,value,options,explanation,type) VALUES('AllowOnShelfHolds', '0', '', 'Allow hold requests to be placed on items that are not on loan', 'YesNo')");
    $dbh->do("INSERT INTO `systempreferences` (variable,value,options,explanation,type) VALUES('AllowHoldsOnDamagedItems', '1', '', 'Allow hold requests to be placed on damaged items', 'YesNo')");
	print "Upgrade to $DBversion done (added new AllowOnShelfHolds syspref)\n";
    SetVersion ($DBversion);
}

$DBversion = "3.00.00.093";
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
    $dbh->do("ALTER TABLE `items` MODIFY COLUMN `copynumber` VARCHAR(32) DEFAULT NULL");
    $dbh->do("ALTER TABLE `deleteditems` MODIFY COLUMN `copynumber` VARCHAR(32) DEFAULT NULL");
	print "Upgrade to $DBversion done (Change data type of items.copynumber to allow free text)\n";
    SetVersion ($DBversion);
}

$DBversion = "3.00.00.094";
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
    $dbh->do("ALTER TABLE `marc_subfield_structure` MODIFY `tagsubfield` VARCHAR(1) NOT NULL DEFAULT '' COLLATE utf8_bin");
	print "Upgrade to $DBversion done (Change Collation of marc_subfield_structure to allow mixed case in subfield labels.)\n";
    SetVersion ($DBversion);
}

$DBversion = "3.00.00.095";
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
    if (C4::Context->preference("marcflavour") eq 'MARC21') {
        $dbh->do("UPDATE marc_subfield_structure SET authtypecode = 'MEETI_NAME' WHERE authtypecode = 'Meeting Name'");
        $dbh->do("UPDATE marc_subfield_structure SET authtypecode = 'CORPO_NAME' WHERE authtypecode = 'CORP0_NAME'");
    }
	print "Upgrade to $DBversion done (fix invalid authority types in MARC21 frameworks [bug 2254])\n";
    SetVersion ($DBversion);
}

$DBversion = "3.00.00.096";
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
    $sth = $dbh->prepare("SHOW COLUMNS FROM borrower_message_preferences LIKE 'wants_digets'");
    $sth->execute();
    if (my $row = $sth->fetchrow_hashref) {
        $dbh->do("ALTER TABLE borrower_message_preferences CHANGE wants_digets wants_digest tinyint(1) NOT NULL default 0");
    }
	print "Upgrade to $DBversion done (fix name borrower_message_preferences.wants_digest)\n";
    SetVersion ($DBversion);
}

$DBversion = '3.00.00.097';
if ( C4::Context->preference('Version') < TransformToNum($DBversion) ) {

    $dbh->do('ALTER TABLE message_queue ADD to_address   mediumtext default NULL');
    $dbh->do('ALTER TABLE message_queue ADD from_address mediumtext default NULL');
    $dbh->do('ALTER TABLE message_queue ADD content_type text');
    $dbh->do('ALTER TABLE message_queue CHANGE borrowernumber borrowernumber int(11) default NULL');

    print "Upgrade to $DBversion done (updating 4 fields in message_queue table)\n";
    SetVersion($DBversion);
}

$DBversion = '3.00.00.098';
if ( C4::Context->preference('Version') < TransformToNum($DBversion) ) {

    $dbh->do(q(DELETE FROM message_transport_types WHERE message_transport_type = 'rss'));
    $dbh->do(q(DELETE FROM message_transports WHERE message_transport_type = 'rss'));

    print "Upgrade to $DBversion done (removing unused RSS message_transport_type)\n";
    SetVersion($DBversion);
}

$DBversion = '3.00.00.099';
if ( C4::Context->preference('Version') < TransformToNum($DBversion) ) {
    $dbh->do("INSERT INTO systempreferences (variable,value,options,explanation,type) VALUES('OpacSuppression', '0', '', 'Turn ON the OPAC Suppression feature, requires further setup, ask your system administrator for details', 'YesNo')");
    print "Upgrade to $DBversion done (Adding OpacSuppression syspref)\n";
    SetVersion($DBversion);
}

$DBversion = '3.00.00.100';
if ( C4::Context->preference('Version') < TransformToNum($DBversion) ) {
	$dbh->do('ALTER TABLE virtualshelves ADD COLUMN lastmodified timestamp NOT NULL default CURRENT_TIMESTAMP on update CURRENT_TIMESTAMP');
    print "Upgrade to $DBversion done (Adding lastmodified column to virtualshelves)\n";
    SetVersion($DBversion);
}

$DBversion = '3.00.00.101';
if ( C4::Context->preference('Version') < TransformToNum($DBversion) ) {
	$dbh->do('ALTER TABLE `overduerules` CHANGE `categorycode` `categorycode` VARCHAR(10) NOT NULL');
	$dbh->do('ALTER TABLE `deletedborrowers` CHANGE `categorycode` `categorycode` VARCHAR(10) NOT NULL');
    print "Upgrade to $DBversion done (Updating columnd definitions for patron category codes in notice/statsu triggers and deletedborrowers tables.)\n";
    SetVersion($DBversion);
}

$DBversion = '3.00.00.102';
if ( C4::Context->preference('Version') < TransformToNum($DBversion) ) {
	$dbh->do('ALTER TABLE serialitems MODIFY `serialid` int(11) NOT NULL AFTER itemnumber' );
	$dbh->do('ALTER TABLE serialitems DROP KEY serialididx' );
	$dbh->do('ALTER TABLE serialitems ADD CONSTRAINT UNIQUE KEY serialitemsidx (itemnumber)' );
	# before setting constraint, delete any unvalid data
	$dbh->do('DELETE from serialitems WHERE serialid not in (SELECT serial.serialid FROM serial)');
	$dbh->do('ALTER TABLE serialitems ADD CONSTRAINT serialitems_sfk_1 FOREIGN KEY (serialid) REFERENCES serial (serialid) ON DELETE CASCADE ON UPDATE CASCADE' );
    print "Upgrade to $DBversion done (Updating serialitems table to allow for multiple items per serial fixing kohabug 2380)\n";
    SetVersion($DBversion);
}

$DBversion = "3.00.00.103";
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
    $dbh->do("DELETE FROM systempreferences WHERE variable='serialsadditems'");
    print "Upgrade to $DBversion done ( Verifying the removal of serialsadditems from syspref fixing kohabug 2219)\n";
    SetVersion ($DBversion);
}

$DBversion = "3.00.00.104";
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
    $dbh->do("DELETE FROM systempreferences WHERE variable='noOPACHolds'");
    print "Upgrade to $DBversion done (remove superseded 'noOPACHolds' system preference per bug 2413)\n";
    SetVersion ($DBversion);
}

$DBversion = '3.00.00.105';
if ( C4::Context->preference("Version") < TransformToNum($DBversion) ) {

    # it is possible that this syspref is already defined since the feature was added some time ago.
    unless ( $dbh->do(q(SELECT variable FROM systempreferences WHERE variable = 'SMSSendDriver')) ) {
        $dbh->do(<<'END_SQL');
INSERT INTO `systempreferences`
  (variable,value,explanation,options,type)
VALUES
('SMSSendDriver','','Sets which SMS::Send driver is used to send SMS messages.','','free')
END_SQL
    }
    print "Upgrade to $DBversion done (added SMSSendDriver system preference)\n";
    SetVersion($DBversion);
}

$DBversion = "3.00.00.106";
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
    $dbh->do("DELETE FROM systempreferences WHERE variable='noOPACHolds'");

# db revision 105 didn't apply correctly, so we're rolling this into 106
	$dbh->do("INSERT INTO `systempreferences`
   (variable,value,explanation,options,type)
	VALUES
	('SMSSendDriver','','Sets which SMS::Send driver is used to send SMS messages.','','free')");

    print "Upgrade to $DBversion done (remove default '0000-00-00' in subscriptionhistory.enddate field)\n";
    $dbh->do("ALTER TABLE `subscriptionhistory` CHANGE `enddate` `enddate` DATE NULL DEFAULT NULL ");
    $dbh->do("UPDATE subscriptionhistory SET enddate=NULL WHERE enddate='0000-00-00'");
    SetVersion ($DBversion);
}

$DBversion = '3.00.00.107';
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
    $dbh->do(<<'END_SQL');
UPDATE systempreferences
  SET explanation = CONCAT( explanation, '. WARNING: this feature is very resource consuming on collections with large numbers of items.' )
  WHERE variable = 'OPACShelfBrowser'
    AND explanation NOT LIKE '%WARNING%'
END_SQL
    $dbh->do(<<'END_SQL');
UPDATE systempreferences
  SET explanation = CONCAT( explanation, '. WARNING: this feature is very resource consuming.' )
  WHERE variable = 'CataloguingLog'
    AND explanation NOT LIKE '%WARNING%'
END_SQL
    $dbh->do(<<'END_SQL');
UPDATE systempreferences
  SET explanation = CONCAT( explanation, '. WARNING: using NoZebra on even modest sized collections is very slow.' )
  WHERE variable = 'NoZebra'
    AND explanation NOT LIKE '%WARNING%'
END_SQL
    print "Upgrade to $DBversion done (warning added to OPACShelfBrowser system preference)\n";
    SetVersion ($DBversion);
}

$DBversion = '3.01.00.000';
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
    print "Upgrade to $DBversion done (start of 3.1)\n";
    SetVersion ($DBversion);
}

$DBversion = '3.01.00.001';
if ( C4::Context->preference('Version') < TransformToNum($DBversion) ) {
    $dbh->do("
        CREATE TABLE hold_fill_targets (
            `borrowernumber` int(11) NOT NULL,
            `biblionumber` int(11) NOT NULL,
            `itemnumber` int(11) NOT NULL,
            `source_branchcode`  varchar(10) default NULL,
            `item_level_request` tinyint(4) NOT NULL default 0,
            PRIMARY KEY `itemnumber` (`itemnumber`),
            KEY `bib_branch` (`biblionumber`, `source_branchcode`),
            CONSTRAINT `hold_fill_targets_ibfk_1` FOREIGN KEY (`borrowernumber`) 
                REFERENCES `borrowers` (`borrowernumber`) ON DELETE CASCADE ON UPDATE CASCADE,
            CONSTRAINT `hold_fill_targets_ibfk_2` FOREIGN KEY (`biblionumber`) 
                REFERENCES `biblio` (`biblionumber`) ON DELETE CASCADE ON UPDATE CASCADE,
            CONSTRAINT `hold_fill_targets_ibfk_3` FOREIGN KEY (`itemnumber`) 
                REFERENCES `items` (`itemnumber`) ON DELETE CASCADE ON UPDATE CASCADE,
            CONSTRAINT `hold_fill_targets_ibfk_4` FOREIGN KEY (`source_branchcode`) 
                REFERENCES `branches` (`branchcode`) ON DELETE CASCADE ON UPDATE CASCADE
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8
    ");
    $dbh->do("
        ALTER TABLE tmp_holdsqueue
            ADD item_level_request tinyint(4) NOT NULL default 0
    ");

    print "Upgrade to $DBversion done (add hold_fill_targets table and a column to tmp_holdsqueue)\n";
    SetVersion($DBversion);
}

$DBversion = '3.01.00.002';
if ( C4::Context->preference('Version') < TransformToNum($DBversion) ) {
    # use statistics where available
    $dbh->do("
        ALTER TABLE statistics ADD KEY  tmp_stats (type, itemnumber, borrowernumber)
    ");
    $dbh->do("
        UPDATE issues iss
        SET issuedate = (
            SELECT max(datetime)
            FROM statistics 
            WHERE type = 'issue'
            AND itemnumber = iss.itemnumber
            AND borrowernumber = iss.borrowernumber
        )
        WHERE issuedate IS NULL;
    ");  
    $dbh->do("ALTER TABLE statistics DROP KEY tmp_stats");

    # default to last renewal date
    $dbh->do("
        UPDATE issues
        SET issuedate = lastreneweddate
        WHERE issuedate IS NULL
        and lastreneweddate IS NOT NULL
    ");

    my $num_bad_issuedates = $dbh->selectrow_array("SELECT COUNT(*) FROM issues WHERE issuedate IS NULL");
    if ($num_bad_issuedates > 0) {
        print STDERR "After the upgrade to $DBversion, there are still $num_bad_issuedates loan(s) with a NULL (blank) loan date. ",
                     "Please check the issues table in your database.";
    }
    print "Upgrade to $DBversion done (bug 2582: set null issues.issuedate to lastreneweddate)\n";
    SetVersion($DBversion);
}

$DBversion = "3.01.00.003";
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
    $dbh->do("INSERT INTO systempreferences (variable,value,explanation,options,type) VALUES('AllowRenewalLimitOverride', '0', 'if ON, allows renewal limits to be overridden on the circulation screen',NULL,'YesNo')");
    print "Upgrade to $DBversion done (add new syspref)\n";
    SetVersion ($DBversion);
}

$DBversion = '3.01.00.004';
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
    $dbh->do("INSERT INTO systempreferences (variable,value,explanation,options,type) VALUES ('OPACDisplayRequestPriority','0','Show patrons the priority level on holds in the OPAC','','YesNo')");
    print "Upgrade to $DBversion done (added OPACDisplayRequestPriority system preference)\n";
    SetVersion ($DBversion);
}

$DBversion = '3.01.00.005';
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
    $dbh->do("
        INSERT INTO `letter` (module, code, name, title, content)
        VALUES('reserves', 'HOLD', 'Hold Available for Pickup', 'Hold Available for Pickup at <<branches.branchname>>', 'Dear <<borrowers.firstname>> <<borrowers.surname>>,\r\n\r\nYou have a hold available for pickup as of <<reserves.waitingdate>>:\r\n\r\nTitle: <<biblio.title>>\r\nAuthor: <<biblio.author>>\r\nCopy: <<items.copynumber>>\r\nLocation: <<branches.branchname>>\r\n<<branches.branchaddress1>>\r\n<<branches.branchaddress2>>\r\n<<branches.branchaddress3>>')
    ");
    $dbh->do("INSERT INTO `message_attributes` (message_attribute_id, message_name, takes_days) values(4, 'Hold Filled', 0)");
    $dbh->do("INSERT INTO `message_transports` (message_attribute_id, message_transport_type, is_digest, letter_module, letter_code) values(4, 'sms', 0, 'reserves', 'HOLD')");
    $dbh->do("INSERT INTO `message_transports` (message_attribute_id, message_transport_type, is_digest, letter_module, letter_code) values(4, 'email', 0, 'reserves', 'HOLD')");
    print "Upgrade to $DBversion done (Add letter for holds notifications)\n";
    SetVersion ($DBversion);
}

$DBversion = '3.01.00.006';
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
    $dbh->do("ALTER TABLE `biblioitems` ADD KEY issn (issn)");
    print "Upgrade to $DBversion done (add index on biblioitems.issn)\n";
    SetVersion ($DBversion);
}

$DBversion = "3.01.00.007";
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
    $dbh->do("UPDATE `systempreferences` SET options='70|10' WHERE variable='intranetmainUserblock'");
    $dbh->do("UPDATE `systempreferences` SET options='70|10' WHERE variable='intranetuserjs'");
    $dbh->do("UPDATE `systempreferences` SET options='70|10' WHERE variable='opacheader'");
    $dbh->do("UPDATE `systempreferences` SET options='70|10' WHERE variable='OpacMainUserBlock'");
    $dbh->do("UPDATE `systempreferences` SET options='70|10' WHERE variable='OpacNav'");
    $dbh->do("UPDATE `systempreferences` SET options='70|10' WHERE variable='opacuserjs'");
    $dbh->do("UPDATE `systempreferences` SET options='30|10', type='Textarea' WHERE variable='OAI-PMH:Set'");
    $dbh->do("UPDATE `systempreferences` SET options='50' WHERE variable='intranetstylesheet'");
    $dbh->do("UPDATE `systempreferences` SET options='50' WHERE variable='intranetcolorstylesheet'");
    $dbh->do("UPDATE `systempreferences` SET options='10' WHERE variable='globalDueDate'");
    $dbh->do("UPDATE `systempreferences` SET type='Integer' WHERE variable='numSearchResults'");
    $dbh->do("UPDATE `systempreferences` SET type='Integer' WHERE variable='OPACnumSearchResults'");
    $dbh->do("UPDATE `systempreferences` SET type='Integer' WHERE variable='ReservesMaxPickupDelay'");
    $dbh->do("UPDATE `systempreferences` SET type='Integer' WHERE variable='TransfersMaxDaysWarning'");
    $dbh->do("UPDATE `systempreferences` SET type='Integer' WHERE variable='StaticHoldsQueueWeight'");
    $dbh->do("UPDATE `systempreferences` SET type='Integer' WHERE variable='holdCancelLength'");
    $dbh->do("UPDATE `systempreferences` SET type='Integer' WHERE variable='XISBNDailyLimit'");
    $dbh->do("UPDATE `systempreferences` SET type='Float' WHERE variable='gist'");
    $dbh->do("UPDATE `systempreferences` SET type='Free' WHERE variable='BakerTaylorUsername'");
    $dbh->do("UPDATE `systempreferences` SET type='Free' WHERE variable='BakerTaylorPassword'");
    $dbh->do("UPDATE `systempreferences` SET type='Textarea', options='70|10' WHERE variable='ISBD'");
    $dbh->do("UPDATE `systempreferences` SET type='Textarea', options='70|10', explanation='Enter a specific hash for NoZebra indexes. Enter : \\\'indexname\\\' => \\\'100a,245a,500*\\\',\\\'index2\\\' => \\\'...\\\'' WHERE variable='NoZebraIndexes'");
    print "Upgrade to $DBversion done (fix display of many sysprefs)\n";
    SetVersion ($DBversion);
}

$DBversion = '3.01.00.008';
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {

    $dbh->do("CREATE TABLE branch_transfer_limits (
                          limitId int(8) NOT NULL auto_increment,
                          toBranch varchar(4) NOT NULL,
                          fromBranch varchar(4) NOT NULL,
                          itemtype varchar(4) NOT NULL,
                          PRIMARY KEY  (limitId)
                          ) ENGINE=InnoDB DEFAULT CHARSET=utf8"
                        );

    $dbh->do("INSERT INTO `systempreferences` ( `variable` , `value` , `options` , `explanation` , `type` ) VALUES ( 'UseBranchTransferLimits', '0', '', 'If ON, Koha will will use the rules defined in branch_transfer_limits to decide if an item transfer should be allowed.', 'YesNo')");

    print "Upgrade to $DBversion done (added branch_transfer_limits table and UseBranchTransferLimits system preference)\n";
    SetVersion ($DBversion);
}

$DBversion = "3.01.00.009";
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
    $dbh->do("ALTER TABLE permissions MODIFY `code` varchar(64) DEFAULT NULL");
    $dbh->do("ALTER TABLE user_permissions MODIFY `code` varchar(64) DEFAULT NULL");
    $dbh->do("INSERT INTO permissions (module_bit, code, description) VALUES ( 1, 'circulate_remaining_permissions', 'Remaining circulation permissions')");
    $dbh->do("INSERT INTO permissions (module_bit, code, description) VALUES ( 1, 'override_renewals', 'Override blocked renewals')");
    print "Upgrade to $DBversion done (added subpermissions for circulate permission)\n";
}

$DBversion = '3.01.00.010';
if ( C4::Context->preference('Version') < TransformToNum($DBversion) ) {
    $dbh->do("ALTER TABLE `borrower_attributes` MODIFY COLUMN `attribute` VARCHAR(64) DEFAULT NULL");
    $dbh->do("ALTER TABLE `borrower_attributes` MODIFY COLUMN `password` VARCHAR(64) DEFAULT NULL");
    print "Upgrade to $DBversion done (bug 2687: increase length of borrower attribute fields)\n";
    SetVersion ($DBversion);
}

$DBversion = '3.01.00.011';
if ( C4::Context->preference('Version') < TransformToNum($DBversion) ) {

    # Yes, the old value was ^M terminated.
    my $bad_value = "function prepareEmailPopup(){\r\n  if (!document.getElementById) return false;\r\n  if (!document.getElementById('reserveemail')) return false;\r\n  rsvlink = document.getElementById('reserveemail');\r\n  rsvlink.onclick = function() {\r\n      doReservePopup();\r\n      return false;\r\n	}\r\n}\r\n\r\nfunction doReservePopup(){\r\n}\r\n\r\nfunction prepareReserveList(){\r\n}\r\n\r\naddLoadEvent(prepareEmailPopup);\r\naddLoadEvent(prepareReserveList);";

    my $intranetuserjs = C4::Context->preference('intranetuserjs');
    if ($intranetuserjs  and  $intranetuserjs eq $bad_value) {
        my $sql = <<'END_SQL';
UPDATE systempreferences
SET value = ''
WHERE variable = 'intranetuserjs'
END_SQL
        $dbh->do($sql);
    }
    print "Upgrade to $DBversion done (removed bogus intranetuserjs syspref)\n";
    SetVersion($DBversion);
}

$DBversion = "3.01.00.012";
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
    $dbh->do("INSERT INTO systempreferences (variable,value,explanation,options,type) VALUES('AllowHoldPolicyOverride', '0', 'Allow staff to override hold policies when placing holds',NULL,'YesNo')");
    $dbh->do("
        CREATE TABLE `branch_item_rules` (
          `branchcode` varchar(10) NOT NULL,
          `itemtype` varchar(10) NOT NULL,
          `holdallowed` tinyint(1) default NULL,
          PRIMARY KEY  (`itemtype`,`branchcode`),
          KEY `branch_item_rules_ibfk_2` (`branchcode`),
          CONSTRAINT `branch_item_rules_ibfk_1` FOREIGN KEY (`itemtype`) REFERENCES `itemtypes` (`itemtype`) ON DELETE CASCADE ON UPDATE CASCADE,
          CONSTRAINT `branch_item_rules_ibfk_2` FOREIGN KEY (`branchcode`) REFERENCES `branches` (`branchcode`) ON DELETE CASCADE ON UPDATE CASCADE
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8
    ");
    $dbh->do("
        CREATE TABLE `default_branch_item_rules` (
          `itemtype` varchar(10) NOT NULL,
          `holdallowed` tinyint(1) default NULL,
          PRIMARY KEY  (`itemtype`),
          CONSTRAINT `default_branch_item_rules_ibfk_1` FOREIGN KEY (`itemtype`) REFERENCES `itemtypes` (`itemtype`) ON DELETE CASCADE ON UPDATE CASCADE
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8
    ");
    $dbh->do("
        ALTER TABLE default_branch_circ_rules
            ADD COLUMN holdallowed tinyint(1) NULL
    ");
    $dbh->do("
        ALTER TABLE default_circ_rules
            ADD COLUMN holdallowed tinyint(1) NULL
    ");
    print "Upgrade to $DBversion done (Add tables and system preferences for holds policies)\n";
    SetVersion ($DBversion);
}

$DBversion = '3.01.00.013';
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
    $dbh->do("
        CREATE TABLE item_circulation_alert_preferences (
            id           int(11) AUTO_INCREMENT,
            branchcode   varchar(10) NOT NULL,
            categorycode varchar(10) NOT NULL,
            item_type    varchar(10) NOT NULL,
            notification varchar(16) NOT NULL,
            PRIMARY KEY (id),
            KEY (branchcode, categorycode, item_type, notification)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8;
    ");

    $dbh->do(q{ ALTER TABLE `message_queue` ADD metadata text DEFAULT NULL           AFTER content;  });
    $dbh->do(q{ ALTER TABLE `message_queue` ADD letter_code varchar(64) DEFAULT NULL AFTER metadata; });

    $dbh->do(q{
        INSERT INTO `letter` (`module`, `code`, `name`, `title`, `content`) VALUES
        ('circulation','CHECKIN','Item Check-in','Check-ins','The following items have been checked in:\r\n----\r\n<<biblio.title>>\r\n----\r\nThank you.');
    });
    $dbh->do(q{
        INSERT INTO `letter` (`module`, `code`, `name`, `title`, `content`) VALUES
        ('circulation','CHECKOUT','Item Checkout','Checkouts','The following items have been checked out:\r\n----\r\n<<biblio.title>>\r\n----\r\nThank you for visiting <<branches.branchname>>.');
    });

    $dbh->do(q{INSERT INTO message_attributes (message_attribute_id, message_name, takes_days) VALUES (5, 'Item Check-in', 0);});
    $dbh->do(q{INSERT INTO message_attributes (message_attribute_id, message_name, takes_days) VALUES (6, 'Item Checkout', 0);});

    $dbh->do(q{INSERT INTO message_transports (message_attribute_id, message_transport_type, is_digest, letter_module, letter_code) VALUES (5, 'email', 0, 'circulation', 'CHECKIN');});
    $dbh->do(q{INSERT INTO message_transports (message_attribute_id, message_transport_type, is_digest, letter_module, letter_code) VALUES (5, 'sms',   0, 'circulation', 'CHECKIN');});
    $dbh->do(q{INSERT INTO message_transports (message_attribute_id, message_transport_type, is_digest, letter_module, letter_code) VALUES (6, 'email', 0, 'circulation', 'CHECKOUT');});
    $dbh->do(q{INSERT INTO message_transports (message_attribute_id, message_transport_type, is_digest, letter_module, letter_code) VALUES (6, 'sms',   0, 'circulation', 'CHECKOUT');});

    print "Upgrade to $DBversion done (data for Email Checkout Slips project)\n";
	 SetVersion ($DBversion);
}

$DBversion = "3.01.00.014";
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
    $dbh->do("ALTER TABLE `branch_transfer_limits` CHANGE `itemtype` `itemtype` VARCHAR( 4 ) CHARACTER SET utf8 COLLATE utf8_general_ci NULL");
    $dbh->do("ALTER TABLE `branch_transfer_limits` ADD `ccode` VARCHAR( 10 ) NULL ;");
    $dbh->do("INSERT INTO `systempreferences` ( `variable` , `value` , `options` , `explanation` , `type` )
    VALUES (
    'BranchTransferLimitsType', 'ccode', 'itemtype|ccode', 'When using branch transfer limits, choose whether to limit by itemtype or collection code.', 'Choice'
    );");
    
    print "Upgrade to $DBversion done ( Updated table for Branch Transfer Limits)\n";
    SetVersion ($DBversion);
}

$DBversion = '3.01.00.015';
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
    $dbh->do("INSERT INTO systempreferences (variable,value,explanation,options,type) VALUES ('SyndeticsClientCode', '0', 'Client Code for using Syndetics Solutions content','','free')");

    $dbh->do("INSERT INTO systempreferences (variable,value,explanation,options,type) VALUES ('SyndeticsEnabled', '0', 'Turn on Syndetics Enhanced Content','','YesNo')");

    $dbh->do("INSERT INTO systempreferences (variable,value,explanation,options,type) VALUES ('SyndeticsCoverImages', '0', 'Display Cover Images from Syndetics','','YesNo')");

    $dbh->do("INSERT INTO systempreferences (variable,value,explanation,options,type) VALUES ('SyndeticsTOC', '0', 'Display Table of Content information from Syndetics','','YesNo')");

    $dbh->do("INSERT INTO systempreferences (variable,value,explanation,options,type) VALUES ('SyndeticsSummary', '0', 'Display Summary Information from Syndetics','','YesNo')");

    $dbh->do("INSERT INTO systempreferences (variable,value,explanation,options,type) VALUES ('SyndeticsEditions', '0', 'Display Editions from Syndetics','','YesNo')");

    $dbh->do("INSERT INTO systempreferences (variable,value,explanation,options,type) VALUES ('SyndeticsExcerpt', '0', 'Display Excerpts and first chapters on OPAC from Syndetics','','YesNo')");

    $dbh->do("INSERT INTO systempreferences (variable,value,explanation,options,type) VALUES ('SyndeticsReviews', '0', 'Display Reviews on OPAC from Syndetics','','YesNo')");

    $dbh->do("INSERT INTO systempreferences (variable,value,explanation,options,type) VALUES ('SyndeticsAuthorNotes', '0', 'Display Notes about the Author on OPAC from Syndetics','','YesNo')");

    $dbh->do("INSERT INTO systempreferences (variable,value,explanation,options,type) VALUES ('SyndeticsAwards', '0', 'Display Awards on OPAC from Syndetics','','YesNo')");

    $dbh->do("INSERT INTO systempreferences (variable,value,explanation,options,type) VALUES ('SyndeticsSeries', '0', 'Display Series information on OPAC from Syndetics','','YesNo')");

    $dbh->do("INSERT INTO systempreferences (variable,value,explanation,options,type) VALUES ('SyndeticsCoverImageSize', 'MC', 'Choose the size of the Syndetics Cover Image to display on the OPAC detail page, MC is Medium, LC is Large','MC|LC','Choice')");

    $dbh->do("INSERT INTO systempreferences (variable,value,explanation,options,type) VALUES ('OPACAmazonCoverImages', '0', 'Display cover images on OPAC from Amazon Web Services','','YesNo')");

    $dbh->do("INSERT INTO systempreferences (variable,value,explanation,options,type) VALUES ('AmazonCoverImages', '0', 'Display Cover Images in Staff Client from Amazon Web Services','','YesNo')");

    $dbh->do("UPDATE systempreferences SET variable='AmazonEnabled' WHERE variable = 'AmazonContent'");

    $dbh->do("UPDATE systempreferences SET variable='OPACAmazonEnabled' WHERE variable = 'OPACAmazonContent'");

    print "Upgrade to $DBversion done (added Syndetics Enhanced Content system preferences)\n";
    SetVersion ($DBversion);
}

$DBversion = "3.01.00.016";
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
    $dbh->do("INSERT INTO `systempreferences` (variable,value,explanation,options,type) VALUES('Babeltheque',0,'Turn ON Babeltheque content  - See babeltheque.com to subscribe to this service','','YesNo')");
    print "Upgrade to $DBversion done (Added Babeltheque syspref)\n";
    SetVersion ($DBversion);
}

$DBversion = "3.01.00.017";
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
    $dbh->do("ALTER TABLE `subscription` ADD `staffdisplaycount` VARCHAR(10) NULL;");
    $dbh->do("ALTER TABLE `subscription` ADD `opacdisplaycount` VARCHAR(10) NULL;");
    $dbh->do("INSERT INTO `systempreferences` ( `variable` , `value` , `options` , `explanation` , `type` )
    VALUES (
    'StaffSerialIssueDisplayCount', '3', '', 'Number of serial issues to display per subscription in the Staff client', 'Integer'
    );");
	$dbh->do("INSERT INTO `systempreferences` ( `variable` , `value` , `options` , `explanation` , `type` )
    VALUES (
    'OPACSerialIssueDisplayCount', '3', '', 'Number of serial issues to display per subscription in the OPAC', 'Integer'
    );");

    print "Upgrade to $DBversion done ( Updated table for Serials Display)\n";
    SetVersion ($DBversion);
}

$DBversion = "3.01.00.018";
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
    $dbh->do("ALTER TABLE deletedborrowers ADD `smsalertnumber` varchar(50) default NULL");
    print "Upgrade to $DBversion done (added deletedborrowers.smsalertnumber, missed in 3.00.00.091)\n";
    SetVersion ($DBversion);
}

$DBversion = "3.01.00.019";
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
        $dbh->do("INSERT INTO `systempreferences` (variable,value,explanation,options,type) VALUES('OPACShowCheckoutName','0','Displays in the OPAC the name of patron who has checked out the material. WARNING: Most sites should leave this off. It is intended for corporate or special sites which need to track who has the item.','','YesNo')");
 
   print "Upgrade to $DBversion done (adding OPACShowCheckoutName systempref)\n";
    SetVersion ($DBversion);
}

$DBversion = "3.01.00.020";
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
    $dbh->do("INSERT INTO systempreferences (variable,value,explanation,options,type)VALUES('LibraryThingForLibrariesID','','See:http://librarything.com/forlibraries/','','free')");
    $dbh->do("INSERT INTO systempreferences (variable,value,explanation,options,type)VALUES('LibraryThingForLibrariesEnabled','0','Enable or Disable Library Thing for Libraries Features','','YesNo')");
    $dbh->do("INSERT INTO systempreferences (variable,value,explanation,options,type)VALUES('LibraryThingForLibrariesTabbedView','0','Put LibraryThingForLibraries Content in Tabs.','','YesNo')");
    print "Upgrade to $DBversion done (adding LibraryThing for Libraries sysprefs)\n";
    SetVersion ($DBversion);
}

$DBversion = "3.01.00.021";
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
    my $enable_reviews = C4::Context->preference('OPACAmazonEnabled') ? '1' : '0';
    $dbh->do("INSERT INTO systempreferences (variable,value,explanation,options,type) VALUES ('OPACAmazonReviews', '$enable_reviews', 'Display Amazon readers reviews on OPAC','','YesNo')");
    print "Upgrade to $DBversion done (adding OPACAmazonReviews syspref)\n";
    SetVersion ($DBversion);
}

$DBversion = '3.01.00.022';
if ( C4::Context->preference('Version') < TransformToNum($DBversion) ) {
    $dbh->do("ALTER TABLE `labels_conf` MODIFY COLUMN `formatstring` mediumtext DEFAULT NULL");
    print "Upgrade to $DBversion done (bug 2945: increase size of labels_conf.formatstring)\n";
    SetVersion ($DBversion);
}

$DBversion = '3.01.00.023';
if ( C4::Context->preference('Version') < TransformToNum($DBversion) ) {
    $dbh->do("ALTER TABLE biblioitems        MODIFY COLUMN isbn VARCHAR(30) DEFAULT NULL");
    $dbh->do("ALTER TABLE deletedbiblioitems MODIFY COLUMN isbn VARCHAR(30) DEFAULT NULL");
    $dbh->do("ALTER TABLE import_biblios     MODIFY COLUMN isbn VARCHAR(30) DEFAULT NULL");
    $dbh->do("ALTER TABLE suggestions        MODIFY COLUMN isbn VARCHAR(30) DEFAULT NULL");
    print "Upgrade to $DBversion done (bug 2765: increase width of isbn column in several tables)\n";
    SetVersion ($DBversion);
}

$DBversion = "3.01.00.024";
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
    $dbh->do("ALTER TABLE labels MODIFY COLUMN batch_id int(10) NOT NULL default 1;");
    print "Upgrade to $DBversion done (change labels.batch_id from varchar to int)\n";
    SetVersion ($DBversion);
}

$DBversion = '3.01.00.025';
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
    $dbh->do("INSERT INTO `systempreferences` ( `variable` , `value` , `options` , `explanation` , `type` ) VALUES ( 'ceilingDueDate', '', '', 'If set, date due will not be past this date.  Enter date according to the dateformat System Preference', 'free')");

    print "Upgrade to $DBversion done (added ceilingDueDate system preference)\n";
    SetVersion ($DBversion);
}

$DBversion = '3.01.00.026';
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
    $dbh->do("INSERT INTO `systempreferences` ( `variable` , `value` , `options` , `explanation` , `type` ) VALUES ( 'numReturnedItemsToShow', '20', '', 'Number of returned items to show on the check-in page', 'Integer')");

    print "Upgrade to $DBversion done (added numReturnedItemsToShow system preference)\n";
    SetVersion ($DBversion);
}

$DBversion = '3.01.00.027';
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
    $dbh->do("ALTER TABLE zebraqueue CHANGE `biblio_auth_number` `biblio_auth_number` bigint(20) unsigned NOT NULL default 0");
    print "Upgrade to $DBversion done (Increased size of zebraqueue biblio_auth_number to address bug 3148.)\n";
    SetVersion ($DBversion);
}

$DBversion = '3.01.00.028';
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
    my $enable_reviews = C4::Context->preference('AmazonEnabled') ? '1' : '0';
    $dbh->do("INSERT INTO systempreferences (variable,value,explanation,options,type) VALUES ('AmazonReviews', '$enable_reviews', 'Display Amazon reviews on staff interface','','YesNo')");
    print "Upgrade to $DBversion done (added AmazonReviews)\n";
    SetVersion ($DBversion);
}

$DBversion = '3.01.00.029';
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
    $dbh->do(q( UPDATE language_rfc4646_to_iso639
                SET iso639_2_code = 'spa'
                WHERE rfc4646_subtag = 'es'
                AND   iso639_2_code = 'rus' )
            );
    print "Upgrade to $DBversion done (fixed bug 2599: using Spanish search limit retrieves Russian results)\n";
    SetVersion ($DBversion);
}

$DBversion = "3.01.00.030";
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
    $dbh->do("INSERT INTO `systempreferences` ( `variable` , `value` , `options` , `explanation` , `type` ) VALUES ( 'AllowNotForLoanOverride', '0', '', 'If ON, Koha will allow the librarian to loan a not for loan item.', 'YesNo')");
    print "Upgrade to $DBversion done (added AllowNotForLoanOverride system preference)\n";
    SetVersion ($DBversion);
}

$DBversion = "3.01.00.031";
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
    $dbh->do("ALTER TABLE branch_transfer_limits
              MODIFY toBranch   varchar(10) NOT NULL,
              MODIFY fromBranch varchar(10) NOT NULL,
              MODIFY itemtype   varchar(10) NULL");
    print "Upgrade to $DBversion done (fix column widths in branch_transfer_limits)\n";
    SetVersion ($DBversion);
}

$DBversion = "3.01.00.032";
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
    $dbh->do(<<ENDOFRENEWAL);
INSERT INTO systempreferences (variable,value,explanation,options,type) VALUES('RenewalPeriodBase', 'now', 'Set whether the renewal date should be counted from the date_due or from the moment the Patron asks for renewal ','date_due|now','Choice');
ENDOFRENEWAL
    print "Upgrade to $DBversion done (Change the field)\n";
    SetVersion ($DBversion);
}

$DBversion = "3.01.00.033";
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
    $dbh->do(q/
        ALTER TABLE borrower_message_preferences
        MODIFY borrowernumber int(11) default NULL,
        ADD    categorycode varchar(10) default NULL AFTER borrowernumber,
        ADD KEY `categorycode` (`categorycode`),
        ADD CONSTRAINT `borrower_message_preferences_ibfk_3` 
                       FOREIGN KEY (`categorycode`) REFERENCES `categories` (`categorycode`) 
                       ON DELETE CASCADE ON UPDATE CASCADE
    /);
    print "Upgrade to $DBversion done (DB changes to allow patron category defaults for messaging preferences)\n";
    SetVersion ($DBversion);
}

$DBversion = "3.01.00.034";
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
    $dbh->do("ALTER TABLE `subscription` ADD COLUMN `graceperiod` INT(11) NOT NULL default '0';");
    print "Upgrade to $DBversion done (Adding graceperiod column to subscription table)\n";
    SetVersion ($DBversion);
}

$DBversion = '3.01.00.035';
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
    $dbh->do(q{ ALTER TABLE `subscription` ADD location varchar(80) NULL DEFAULT '' AFTER callnumber; });
   print "Upgrade to $DBversion done (Adding location to subscription table)\n";
    SetVersion ($DBversion);
}

$DBversion = '3.01.00.036';
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
    $dbh->do("UPDATE systempreferences SET explanation = 'Choose the default detail view in the staff interface; choose between normal, labeled_marc, marc or isbd'
              WHERE variable = 'IntranetBiblioDefaultView'
              AND   explanation = 'IntranetBiblioDefaultView'");
    $dbh->do("UPDATE systempreferences SET type = 'Choice', options = 'normal|marc|isbd|labeled_marc'
              WHERE variable = 'IntranetBiblioDefaultView'");
    $dbh->do("INSERT INTO systempreferences (variable,value,explanation,options,type)VALUES('viewISBD','1','Allow display of ISBD view of bibiographic records','','YesNo')");
    $dbh->do("INSERT INTO systempreferences (variable,value,explanation,options,type)VALUES('viewLabeledMARC','0','Allow display of labeled MARC view of bibiographic records','','YesNo')");
    $dbh->do("INSERT INTO systempreferences (variable,value,explanation,options,type)VALUES('viewMARC','1','Allow display of MARC view of bibiographic records','','YesNo')");
    print "Upgrade to $DBversion done (new viewISBD, viewLabeledMARC, viewMARC sysprefs and tweak IntranetBiblioDefaultView)\n";
    SetVersion ($DBversion);
}

$DBversion = '3.01.00.037';
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
    $dbh->do('ALTER TABLE authorised_values ADD KEY `lib` (`lib`)');
    $dbh->do("INSERT INTO systempreferences (variable,value,explanation,options,type)VALUES('FilterBeforeOverdueReport','0','Do not run overdue report until filter selected','','YesNo')");
    SetVersion ($DBversion);
    print "Upgrade to $DBversion done (added FilterBeforeOverdueReport syspref and new index on authorised_values)\n";
}

$DBversion = "3.01.00.038";
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
    # update branches table
    # 
    $dbh->do("ALTER TABLE branches ADD `branchzip` varchar(25) default NULL AFTER `branchaddress3`");
    $dbh->do("ALTER TABLE branches ADD `branchcity` mediumtext AFTER `branchzip`");
    $dbh->do("ALTER TABLE branches ADD `branchcountry` text AFTER `branchcity`");
    $dbh->do("ALTER TABLE branches ADD `branchurl` mediumtext AFTER `branchemail`");
    $dbh->do("ALTER TABLE branches ADD `branchnotes` mediumtext AFTER `branchprinter`");
    print "Upgrade to $DBversion done (add ZIP, city, country, URL, and notes column to branches)\n";
    SetVersion ($DBversion);
}

$DBversion = '3.01.00.039';
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
    $dbh->do("INSERT INTO systempreferences (variable,value,options,explanation,type)VALUES('SpineLabelFormat', '<itemcallnumber><copynumber>', '30|10', 'This preference defines the format for the quick spine label printer. Just list the fields you would like to see in the order you would like to see them, surrounded by <>, for example <itemcallnumber>.', 'Textarea')");
    $dbh->do("INSERT INTO systempreferences (variable,value,options,explanation,type)VALUES('SpineLabelAutoPrint', '0', '', 'If this setting is turned on, a print dialog will automatically pop up for the quick spine label printer.', 'YesNo')");
    SetVersion ($DBversion);
    print "Upgrade to $DBversion done (added SpineLabelFormat and SpineLabelAutoPrint sysprefs)\n";
}

$DBversion = '3.01.00.040';
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
    $dbh->do("INSERT INTO systempreferences (variable,value,explanation,options,type)VALUES('AllowHoldDateInFuture','0','If set a date field is displayed on the Hold screen of the Staff Interface, allowing the hold date to be set in the future.','','YesNo')");
    $dbh->do("INSERT INTO systempreferences (variable,value,explanation,options,type)VALUES('OPACAllowHoldDateInFuture','0','If set, along with the AllowHoldDateInFuture system preference, OPAC users can set the date of a hold to be in the future.','','YesNo')");
    SetVersion ($DBversion);
    print "Upgrade to $DBversion done (AllowHoldDateInFuture and OPACAllowHoldDateInFuture sysprefs)\n";
}

$DBversion = '3.01.00.041';
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
    $dbh->do("INSERT INTO `systempreferences` (variable,value,explanation,options,type) VALUES('AWSPrivateKey','','See:  http://aws.amazon.com.  Note that this is required after 2009/08/15 in order to retrieve any enhanced content other than book covers from Amazon.','','free')");
    SetVersion ($DBversion);
    print "Upgrade to $DBversion done (added AWSPrivateKey syspref - note that if you use enhanced content from Amazon, this should be set right away.)\n";
}

$DBversion = '3.01.00.042';
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
    $dbh->do("INSERT INTO `systempreferences` (variable,value,explanation,options,type) VALUES('OPACFineNoRenewals','99999','Fine Limit above which user canmot renew books via OPAC','','Integer')");
    SetVersion ($DBversion);
    print "Upgrade to $DBversion done (added OPACFineNoRenewals syspref)\n";
}

$DBversion = '3.01.00.043';
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
    $dbh->do('ALTER TABLE items ADD COLUMN permanent_location VARCHAR(80) DEFAULT NULL AFTER location');
    $dbh->do('UPDATE items SET permanent_location = location');
    $dbh->do("INSERT INTO `systempreferences` ( `variable` , `value` , `options` , `explanation` , `type` ) VALUES ( 'NewItemsDefaultLocation', '', '', 'If set, all new items will have a location of the given Location Code ( Authorized Value type LOC )', '')");
    $dbh->do("INSERT INTO `systempreferences` ( `variable` , `value` , `options` , `explanation` , `type` ) VALUES ( 'InProcessingToShelvingCart', '0', '', 'If set, when any item with a location code of PROC is ''checked in'', it''s location code will be changed to CART.', 'YesNo')");
    $dbh->do("INSERT INTO `systempreferences` ( `variable` , `value` , `options` , `explanation` , `type` ) VALUES ( 'ReturnToShelvingCart', '0', '', 'If set, when any item is ''checked in'', it''s location code will be changed to CART.', 'YesNo')");
    SetVersion ($DBversion);
    print "Upgrade to $DBversion done (amended Item added NewItemsDefaultLocation, InProcessingToShelvingCart, ReturnToShelvingCart sysprefs)\n";
}

$DBversion = '3.01.00.044';
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
    $dbh->do("INSERT INTO systempreferences (variable,value,explanation,options,type)VALUES( 'DisplayClearScreenButton', '0', 'If set to yes, a clear screen button will appear on the circulation page.', 'If set to yes, a clear screen button will appear on the circulation page.', 'YesNo')");
    SetVersion ($DBversion);
    print "Upgrade to $DBversion done (added DisplayClearScreenButton system preference)\n";
}

$DBversion = '3.01.00.045';
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
    $dbh->do("INSERT INTO systempreferences (variable,value,options,explanation,type)VALUES('HidePatronName', '0', '', 'If this is switched on, patron''s cardnumber will be shown instead of their name on the holds and catalog screens', 'YesNo')");
    SetVersion ($DBversion);
    print "Upgrade to $DBversion done (added a preference to hide the patrons name in the staff catalog)";
}

$DBversion = "3.01.00.046";
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
    # update borrowers table
    # 
    $dbh->do("ALTER TABLE borrowers ADD `country` text AFTER zipcode");
    $dbh->do("ALTER TABLE borrowers ADD `B_country` text AFTER B_zipcode");
    $dbh->do("ALTER TABLE deletedborrowers ADD `country` text AFTER zipcode");
    $dbh->do("ALTER TABLE deletedborrowers ADD `B_country` text AFTER B_zipcode");
    print "Upgrade to $DBversion done (add country and B_country to borrowers)\n";
    SetVersion ($DBversion);
}

$DBversion = '3.01.00.047';
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
    $dbh->do("ALTER TABLE items MODIFY itemcallnumber varchar(255);");
    $dbh->do("ALTER TABLE deleteditems MODIFY itemcallnumber varchar(255);");
    $dbh->do("ALTER TABLE tmp_holdsqueue MODIFY itemcallnumber varchar(255);");
    SetVersion ($DBversion);
    print " Upgrade to $DBversion done (bug 2761: change max length of itemcallnumber to 255 from 30)\n";
}

$DBversion = '3.01.00.048';
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
    $dbh->do("UPDATE userflags SET flagdesc='View Catalog (Librarian Interface)' WHERE bit=2;");
    $dbh->do("UPDATE userflags SET flagdesc='Edit Catalog (Modify bibliographic/holdings data)' WHERE bit=9;");
    $dbh->do("UPDATE userflags SET flagdesc='Allow to edit authorities' WHERE bit=14;");
    $dbh->do("UPDATE userflags SET flagdesc='Allow to access to the reports module' WHERE bit=16;");
    $dbh->do("UPDATE userflags SET flagdesc='Allow to manage serials subscriptions' WHERE bit=15;");
    SetVersion ($DBversion);
    print " Upgrade to $DBversion done (bug 2611: fix spelling/capitalization in permission flag descriptions)\n";
}

$DBversion = '3.01.00.049';
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
    $dbh->do("UPDATE permissions SET description = 'Perform inventory (stocktaking) of your catalog' WHERE code = 'inventory';");
     SetVersion ($DBversion);
    print "Upgrade to $DBversion done (bug 2611: changed catalogue to catalog per the standard)\n";
}

$DBversion = '3.01.00.050';
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
    $dbh->do("INSERT INTO `systempreferences` (variable,value,explanation,options,type) VALUES ('OPACSearchForTitleIn','<li class=\"yuimenuitem\">\n<a target=\"_blank\" class=\"yuimenuitemlabel\" href=\"http://worldcat.org/search?q=TITLE\">Other Libraries (WorldCat)</a></li>\n<li class=\"yuimenuitem\">\n<a class=\"yuimenuitemlabel\" href=\"http://www.scholar.google.com/scholar?q=TITLE\" target=\"_blank\">Other Databases (Google Scholar)</a></li>\n<li class=\"yuimenuitem\">\n<a class=\"yuimenuitemlabel\" href=\"http://www.bookfinder.com/search/?author=AUTHOR&amp;title=TITLE&amp;st=xl&amp;ac=qr\" target=\"_blank\">Online Stores (Bookfinder.com)</a></li>','Enter the HTML that will appear in the ''Search for this title in'' box on the detail page in the OPAC.  Enter TITLE, AUTHOR, or ISBN in place of their respective variables in the URL.  Leave blank to disable ''More Searches'' menu.','70|10','Textarea');");
    SetVersion ($DBversion);
    print "Upgrade to $DBversion done (bug 1934: Add OPACSearchForTitleIn syspref)\n";
}

$DBversion = '3.01.00.051';
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
    $dbh->do("UPDATE systempreferences SET explanation='Fine limit above which user cannot renew books via OPAC' WHERE variable='OPACFineNoRenewals';");
    $dbh->do("UPDATE systempreferences SET explanation='If set to ON, a clear screen button will appear on the circulation page.' WHERE variable='DisplayClearScreenButton';");
    SetVersion ($DBversion);
    print "Upgrade to $DBversion done (fixed typos in new sysprefs)\n";
}

$DBversion = '3.01.00.052';
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
    $dbh->do('ALTER TABLE deleteditems ADD COLUMN permanent_location VARCHAR(80) DEFAULT NULL AFTER location');
    SetVersion ($DBversion);
    print "Upgrade to $DBversion done (bug 3481: add permanent_location column to deleteditems)\n";
}

$DBversion = '3.01.00.053';
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
    my $upgrade_script = C4::Context->config("intranetdir") . "/installer/data/mysql/labels_upgrade.pl";
    system("perl $upgrade_script");
    print "Upgrade to $DBversion done (Migrated labels tables and data to new schema.) NOTE: All existing label batches have been assigned to the first branch in the list of branches. This is ONLY true of migrated label batches.\n";
    SetVersion ($DBversion);
}

$DBversion = '3.01.00.054';
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
    $dbh->do("ALTER TABLE borrowers ADD `B_address2` text AFTER B_address");
    $dbh->do("ALTER TABLE borrowers ADD `altcontactcountry` text AFTER altcontactzipcode");
    $dbh->do("ALTER TABLE deletedborrowers ADD `B_address2` text AFTER B_address");
    $dbh->do("ALTER TABLE deletedborrowers ADD `altcontactcountry` text AFTER altcontactzipcode");
    SetVersion ($DBversion);
    print "Upgrade to $DBversion done (bug 1600, bug 3454: add altcontactcountry and B_address2 to borrowers and deletedborrowers)\n";
}

$DBversion = '3.01.00.055';
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
    $dbh->do(qq|UPDATE systempreferences set explanation='Enter the HTML that will appear in the ''Search for this title in'' box on the detail page in the OPAC.  Enter {TITLE}, {AUTHOR}, or {ISBN} in place of their respective variables in the URL. Leave blank to disable ''More Searches'' menu.', value='<li><a  href="http://worldcat.org/search?q={TITLE}" target="_blank">Other Libraries (WorldCat)</a></li>\n<li><a href="http://www.scholar.google.com/scholar?q={TITLE}" target="_blank">Other Databases (Google Scholar)</a></li>\n<li><a href="http://www.bookfinder.com/search/?author={AUTHOR}&amp;title={TITLE}&amp;st=xl&amp;ac=qr" target="_blank">Online Stores (Bookfinder.com)</a></li>' WHERE variable='OPACSearchForTitleIn'|);
    SetVersion ($DBversion);
    print "Upgrade to $DBversion done (changed OPACSearchForTitleIn per requests in bug 1934)\n";
}

$DBversion = '3.01.00.056';
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
    $dbh->do("INSERT INTO `systempreferences` (variable,value,explanation,options,type) VALUES ('OPACPatronDetails','1','If OFF the patron details tab in the OPAC is disabled.','','YesNo');");
    SetVersion ($DBversion);
    print "Upgrade to $DBversion done (Bug 1172 : Add OPACPatronDetails syspref)\n";
}

$DBversion = '3.01.00.057';
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
    $dbh->do("INSERT INTO `systempreferences` (variable,value,explanation,options,type) VALUES ('OPACFinesTab','1','If OFF the patron fines tab in the OPAC is disabled.','','YesNo');");
    SetVersion ($DBversion);
    print "Upgrade to $DBversion done (Bug 2576 : Add OPACFinesTab syspref)\n";
}

$DBversion = '3.01.00.058';
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
    $dbh->do("ALTER TABLE `language_subtag_registry` ADD `id` INT( 11 ) NOT NULL AUTO_INCREMENT PRIMARY KEY;");
    $dbh->do("ALTER TABLE `language_rfc4646_to_iso639` ADD `id` INT( 11 ) NOT NULL AUTO_INCREMENT PRIMARY KEY;");
    $dbh->do("ALTER TABLE `language_descriptions` ADD `id` INT( 11 ) NOT NULL AUTO_INCREMENT PRIMARY KEY;");
    SetVersion ($DBversion);
    print "Upgrade to $DBversion done (Added primary keys to language tables)\n";
}

$DBversion = '3.01.00.059';
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
    $dbh->do("INSERT INTO systempreferences (variable,value,options,explanation,type)VALUES('DisplayOPACiconsXSLT', '1', '', 'If ON, displays the format, audience, type icons in XSLT MARC21 results and display pages.', 'YesNo')");
    SetVersion ($DBversion);
    print "Upgrade to $DBversion done (added DisplayOPACiconsXSLT sysprefs)\n";
}

$DBversion = '3.01.00.060';
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
    $dbh->do("INSERT INTO systempreferences (variable,value,explanation,options,type) VALUES('AllowAllMessageDeletion','0','Allow any Library to delete any message','','YesNo');");
    $dbh->do('DROP TABLE IF EXISTS messages');
    $dbh->do("CREATE TABLE messages ( `message_id` int(11) NOT NULL auto_increment,
        `borrowernumber` int(11) NOT NULL,
        `branchcode` varchar(4) default NULL,
        `message_type` varchar(1) NOT NULL,
        `message` text NOT NULL,
        `message_date` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY (`message_id`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8");

	print "Upgrade to $DBversion done ( Added AllowAllMessageDeletion syspref and messages table )\n";
    SetVersion ($DBversion);
}

$DBversion = '3.01.00.061';
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
    $dbh->do("INSERT INTO systempreferences (variable,value,explanation,options,type)VALUES('ShowPatronImageInWebBasedSelfCheck', '0', 'If ON, displays patron image when a patron uses web-based self-checkout', '', 'YesNo')");
	print "Upgrade to $DBversion done ( Added ShowPatronImageInWebBasedSelfCheck system preference )\n";
    SetVersion ($DBversion);
}

# get around KohaPTFSVersion schism
{
    my $sth = $dbh->prepare('SELECT value FROM systempreferences WHERE variable = "KohaPTFSVersion";');
    $sth->execute();
    last if ($sth->rows() != 1);
    my $row = $sth->fetchrow_arrayref();
    my $version = $row->[0];
    my $newversion;

    if ( $version eq '1.0' ) {
        $newversion = '4.00.99.999';
    } elsif ( $version eq '1.1' ) {
        $newversion = '4.01.00.005';
    } elsif ( $version eq '1.1.0.1' ) {
        $newversion = '4.01.00.007';
    } else {
        die "Unknown KohaPTFSVersion: '%s'\n", $version;
    }
    printf "Found KohaPTFSVersion %s. Updating to %s.\n", $version, $newversion;
    SetVersion($newversion);
    C4::Context->clear_syspref_cache('Version');
}

$DBversion = '4.00.00.000';
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
    $dbh -> do("INSERT INTO systempreferences (variable,value,explanation,options,type) VALUES ('PatronDisplayReturn','1','If ON,allows items to be returned in the patron details display checkout list.','','YesNo');");
    $dbh -> do("INSERT INTO systempreferences (variable,value,explanation,options,type) VALUES ('opacbookbagName','Cart','Allows libraries to define a different name for the OPAC Cart feature,such as Bookbag or Personal Shelf. If no name is defined,it will default to Cart.','70|10','Textarea');");
    $dbh -> do("INSERT INTO systempreferences (variable,value,explanation,options,type) VALUES ('DisplayMultiPlaceHold','1','If ON,displays the Place Hold button at the top of the search results list in staff and OPAC. Sites whose policies require tighter control over holds may want to turn this option off and limit users to placing holds one at a time.','','YesNo');");
    $dbh -> do("INSERT INTO systempreferences (variable,value,explanation,options,type) VALUES ('OPACAdvancedSearchTypes','itemtypes','Select which set of fields comprise the Type limit in the OPAC advanced search','itemtypes|ccode','Choice');");
    $dbh -> do("INSERT INTO systempreferences (variable,value,explanation,options,type) VALUES ('HoldButtonConfirm','1','Display Confirm button when hold triggered. Leave either this setting or HoldButtonPrintConfirm on.','','YesNo');");
    $dbh -> do("INSERT INTO systempreferences (variable,value,explanation,options,type) VALUES ('HoldButtonPrintConfirm','1','Display Confirm and Print Slip button when hold triggered. Leave either this setting or HoldButtonConfirm on.','','YesNo');");
    $dbh -> do("INSERT INTO systempreferences (variable,value,explanation,options,type) VALUES ('HoldButtonIgnore','1','Display Ignore button when hold triggered.','','YesNo');");
    $dbh -> do("INSERT INTO systempreferences (variable,value,explanation,options,type) VALUES ('opacmsgtab','1','If on,enables display of My Messaging tab in OPAC patron account and the email/text message settings in OPAC user update tab.','','YesNo');");
    $dbh -> do("INSERT INTO systempreferences (variable,value,explanation,options,type) VALUES ('AutoSelfCheckAllowed','0','For corporate and special libraries which want web-based self-check available from any PC without the need for a manual staff login. Most libraries will want to leave this turned off. If on,requires self-check ID and password to be entered in AutoSelfCheckID and AutoSelfCheckPass sysprefs.','','YesNo');");
    $dbh -> do("INSERT INTO systempreferences (variable,value,explanation,options,type) VALUES ('AutoSelfCheckID','','Staff ID with circulation rights to be used for automatic web-based self-check. Only applies if AutoSelfCheckAllowed syspref is turned on.','70|10','Textarea');");
    $dbh -> do("INSERT INTO systempreferences (variable,value,explanation,options,type) VALUES ('AutoSelfCheckPass','','Password to be used for automatic web-based self-check. Only applies if AutoSelfCheckAllowed syspref is turned on.','70|10','Textarea');");
    $dbh -> do("INSERT INTO systempreferences (variable,value,explanation,options,type) VALUES ('OPACFinesTab','1','If OFF the patron fines tab in the OPAC is disabled.','','YesNo');");
    $dbh -> do("INSERT INTO systempreferences (variable,value,explanation,options,type) VALUES ('EnableOverdueAccruedAmount','0','If ON,splits fines and charges into amount due and overdue accrued amount.  The latter amount can not be paid until the item is checked in.','','YesNo');");
    $dbh -> do("INSERT INTO systempreferences (variable,value,explanation,options,type) VALUES ('CircFinesBreakdown','1','Show a breakdown of fines by type on the checkout page','','YesNo');");
    $dbh -> do("INSERT INTO systempreferences (variable,value,explanation,options,type) VALUES ('EnableOwedNotification',0,'If ON,allows a notification to be sent on total amount owed.  OwedNotificationValue syspref will need to be set to the desired amount.',NULL,'YesNo');");
    $dbh -> do("INSERT INTO systempreferences (variable,value,explanation,options,type) VALUES ('OwedNotificationValue',25.00,'Amount owed to receive a notification.  To work,EnableOwedNotification syspref will need to be turned ON.',NULL,'free');");
    $dbh -> do("INSERT INTO systempreferences (variable,value,explanation,options,type)VALUES ('BCCAllNotices','','If set,sends a blind carbon of every email sent to the specified address','','free');");
    $dbh -> do("INSERT INTO systempreferences (variable,value,options,explanation,type) VALUES ('CheckoutTimeout','0','','Value in seconds before a window pops up on the circ screen asking the librarian if they would like to continue using this record or to search for a new borrower.','Integer');");
    $dbh -> do("INSERT INTO systempreferences (variable,value,options,explanation,type) VALUES ('AllowOverrideLogin','0','','If ON,Koha will allow staff members to temporarily log in as a user with more rights in certain situations','YesNo');");
    $dbh -> do("INSERT INTO systempreferences (variable,value,options,explanation,type) VALUES ('AllowDueDateInPast','0','','Allows a due date to be set in the past for testing.','YesNo');");
    $dbh -> do("INSERT INTO systempreferences (variable,value,options,explanation,type) VALUES ('AllowCheckInDateChange','1','','Allow modification of checkin date/time','YesNo');");
    $dbh -> do("INSERT INTO systempreferences (variable,value,options,explanation,type) VALUES ('BatchMemberDeleteFineThreshhold','0.0','','Any borrower with an amount of fines greater than this value cannot be deleted via batch borrower deleting.','Float');");
    $dbh -> do("INSERT INTO systempreferences (variable,value,options,explanation,type) VALUES ('ShowPatronSearchBySQL','0','','If turned on,a search by sql box will appear on the Patrons search pages.','YesNo');");
    $dbh -> do("INSERT INTO systempreferences (variable,value,options,explanation,type) VALUES ('BatchMemberDeletePaidDebtCollections','0','','If on,the batch delete will refuse to delete members with unpaid fines before being put in debt collections.','YesNo');");
    $dbh -> do("INSERT INTO systempreferences (variable,value,options,explanation,type) VALUES ('DisableHoldsIssueOverrideUnlessAuthorised','1','','If this preference is enabled,it will block staff ability to checkout items on hold,but includes a superlibrarian override.','YesNo');");
    $dbh -> do("INSERT INTO systempreferences (variable,value,options,explanation,type) VALUES ('UseGranularMaxFines','0','','If enabled,this allows you to define the max for an item by a combination of itemtype & patroncategory.','YesNo');");
    $dbh -> do("INSERT INTO systempreferences (variable,value,options,explanation,type) VALUES ('UseGranularMaxHolds','0','','If enabled,this allows you to define the maximum number of holds by a combination of itemtype & patroncategory.','YesNo');");
    $dbh -> do("INSERT INTO systempreferences (variable,value,options,explanation,type) VALUES ('WarnOnlyOnMaxFine','0','','If UseGranularMaxFines and WarnOnlyOnMaxFine are both enabled,fine warnings will only occur when the fine for an item hits the max_fine attribute set in issuingrules.','YesNo');");
    $dbh -> do("INSERT INTO systempreferences (variable,value,options,explanation,type) VALUES ('DisplayInitials','1','','Ability to turn the initials field on/off in patron screen','YesNo');");
    $dbh -> do("INSERT INTO systempreferences (variable,value,options,explanation,type) VALUES ('DisplayOthernames','1','','Ability to turn the othernames field on/off in patron screen','YesNo');");
    $dbh -> do("INSERT INTO systempreferences (variable,value,options,explanation,type) VALUES ('AllowReadingHistoryAnonymizing','1','','Allows a borrower to optionally delete his or her reading history.','YesNo');");
    $dbh -> do("INSERT INTO systempreferences (variable,value,options,explanation,type) VALUES ('ClaimsReturnedValue',5,'','Lost value of Claims Returned,to be ignored by fines cron job','Integer');");
    $dbh -> do("INSERT INTO systempreferences (variable,value,options,explanation,type) VALUES ('MarkLostItemsReturned',0,'','If ON,will check in items (removing them from a patron list of checked out items) when they are marked as lost','YesNo');");
    $dbh -> do("INSERT INTO systempreferences (variable,value,options,explanation,type) VALUES ('ResetOpacInactivityTimeout','0','','This will set an inactivity timer that will reset the OPAC to the main OPAC screen after the specified amount of time has passed since mouse movement was last detected. The value is 0 for disabled,or a positive integer for the number of seconds of inactivity before resetting the OPAC.','Integer');");
    $dbh -> do("INSERT INTO systempreferences (variable,value,options,explanation,type) VALUES ('AllowMultipleHoldsPerBib','','','This allows multiple items per record to be placed on hold by a single patron. To enable,enter a list of space separated itemtype codes in the field (i.e. MAG JMAG YMAG). Useful for magazines,encyclopedias and other bibs where the attached items are not identical.','');");
    $dbh -> do("INSERT INTO systempreferences (variable,value,options,explanation,type) VALUES ('OPACXSLTDetailsDisplay',1,NULL,' Enable XSL stylesheet control over details page display on OPAC','YesNo');");
    $dbh -> do("INSERT INTO systempreferences (variable,value,options,explanation,type) VALUES ('OPACXSLTResultsDisplay',1,NULL,' Enable XSL stylesheet control over results page display on OPAC','YesNo');");
    $dbh -> do("INSERT INTO systempreferences (variable,value,explanation,type) VALUES ('OPACSearchSuggestionsCount','5','If greater than 0, sets the number of search suggestions provided.','Integer');");
    $dbh -> do("INSERT INTO systempreferences (variable,value,explanation,type) VALUES ('StaffSearchSuggestionsCount','5','If greater than 0, sets the number of search suggestions provided.','Integer');");
	print "Upgrade to $DBversion done ( Added slew of system preferences )\n";
    SetVersion ($DBversion);
}

$DBversion = '4.00.00.001';
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
    $dbh -> do("ALTER TABLE reserves ADD COLUMN reservenumber int(11) NOT NULL FIRST;");
    $dbh -> do("ALTER TABLE reserves ADD COLUMN expirationdate date;");
    $dbh -> do("ALTER TABLE old_reserves ADD COLUMN reservenumber int(11) NOT NULL FIRST;");
    $dbh -> do("ALTER TABLE old_reserves ADD COLUMN expirationdate date;");

    # add reserve numbers
    $dbh->{AutoCommit} = 0 ;
    $dbh->do("LOCK TABLES reserves WRITE, old_reserves WRITE" );
# now populate unique keys in reserves & old_reserves.
    my $sth_old_reserves = $dbh->prepare("SELECT borrowernumber,priority,biblionumber ,reservedate,timestamp FROM old_reserves");
    my $sth_reserves = $dbh->prepare("SELECT borrowernumber,priority, biblionumber ,reservedate,timestamp FROM reserves");
    my $sth_old_reserves_update = $dbh->prepare("UPDATE `old_reserves` SET reservenumber=? where borrowernumber=? and priority = ? AND biblionumber =? AND reservedate=? AND timestamp=? AND (reservenumber IS NULL OR reservenumber=0) limit 1");
    my $sth_reserves_update = $dbh->prepare("UPDATE `reserves` SET reservenumber=? where borrowernumber=? and priority = ? AND biblionumber =? AND reservedate=? AND timestamp=? AND (reservenumber IS NULL OR reservenumber=0) limit 1");
    my $id = 0;
    $sth_old_reserves->execute();
    my ($bornum, $priority , $biblionumber, $reservedate, $timestamp);
    $sth_old_reserves->bind_columns(\$bornum,\$priority ,\$biblionumber ,\$reservedate,\$timestamp);
    while($sth_old_reserves->fetchrow_arrayref){
        $sth_old_reserves_update->execute(++$id,$bornum,$priority, $biblionumber , $reservedate, $timestamp);
    }
    $sth_old_reserves->finish();

    $sth_reserves->execute();
    $sth_reserves->bind_columns(\$bornum,\$priority,\$biblionumber ,\$reservedate,\$timestamp);
    while($sth_reserves->fetchrow_arrayref){
        $sth_reserves_update->execute(++$id,$bornum,$priority, $biblionumber , $reservedate, $timestamp);
    }
    $sth_reserves->finish();
    my $sth_delete_old_reserves = $dbh->prepare("delete from old_reserves where reservenumber is null or reservenumber = 0");
    $sth_delete_old_reserves->execute();
    $sth_delete_old_reserves->finish();

    my $sth_delete_reserves = $dbh->prepare("delete from reserves where reservenumber is null or reservenumber = 0 ");
    $sth_delete_reserves->execute();
    $sth_delete_reserves->finish();

    $dbh->do("COMMIT ");
    $dbh->do("UNLOCK TABLES");
    # Now that we have unique keys, we can add the PK.
    $dbh->do("ALTER TABLE reserves MODIFY COLUMN reservenumber INT(11) NOT NULL AUTO_INCREMENT PRIMARY KEY");   

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
        expirationdate date,
        PRIMARY KEY  (reservenumber),
        KEY borrowernumber (borrowernumber),
        KEY biblionumber (biblionumber),
        KEY itemnumber (itemnumber),
        KEY branchcode (branchcode),
        CONSTRAINT reserves_suspended_ibfk_1 FOREIGN KEY (borrowernumber) REFERENCES borrowers (borrowernumber) ON DELETE CASCADE ON UPDATE CASCADE,
        CONSTRAINT reserves_suspended_ibfk_2 FOREIGN KEY (biblionumber) REFERENCES biblio (biblionumber) ON DELETE CASCADE ON UPDATE CASCADE,
        CONSTRAINT reserves_suspended_ibfk_4 FOREIGN KEY (branchcode) REFERENCES branches (branchcode) ON DELETE CASCADE ON UPDATE CASCADE
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8;");

	print "Upgrade to $DBversion done ( Reserve suspension )\n";
    SetVersion ($DBversion);
}

$DBversion = '4.00.00.002';
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
    $dbh -> do("DELETE FROM z3950servers where name='NEW YORK UNIVERSITY LIBRARIES' or name='NEW YORK PUBLIC LIBRARY';");
    $dbh -> do("INSERT INTO z3950servers
        (host, port, db, userid, password, name, id, checked, rank, syntax, encoding) VALUES 
        ('hopkins1.bobst.nyu.edu',9991,'NYU01PUB','','','NEW YORK UNIVERSITY LIBRARIES',5,0,0,'USMARC','MARC-8'),
        ('catalog.nypl.org',210,'innopac','','','NEW YORK PUBLIC LIBRARY',7,0,0,'USMARC','MARC-8');");

	print "Upgrade to $DBversion done ( Modifying NYU and NYPL Z39.50 servers)\n";
    SetVersion ($DBversion);
}

# This prompts all updates to have to redefine their user permissions structure. Not a friendly
# solution and not necessary since there is no divergence. Commented out by CTF.
# Update:  skip truncate, just do INSERT IGNORE, per MM -hQ
$DBversion = '4.00.00.003';
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
###
#    $dbh -> do("TRUNCATE permissions;");
###
    $dbh -> do("
    INSERT IGNORE INTO permissions (module_bit, code, description) VALUES
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
        (13, 'schedule_tasks', 'Schedule tasks to run');");

	print "Upgrade to $DBversion done ( Rewrite 'permissions' table )\n";
    SetVersion ($DBversion);
}

$DBversion = '4.00.00.004';
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
    $dbh -> do("INSERT INTO letter (module,code,name,title,content) VALUES ('reserves','DAMAGEDHOLD','Damaged Item Removed From Holds Queue','Damaged Item Removed From Holds Queue','The following item was returned damaged and is out of circulation; your hold has been cancelled.\r\n\r\n<<biblio.title>>\r\n\r\n');");

	print "Upgrade to $DBversion done ( Damaged item hold cancellation letter template )\n";
    SetVersion ($DBversion);
}

$DBversion = '4.00.00.005';
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
    $dbh -> do("INSERT INTO message_transport_types (message_transport_type) values ('print');");

	print "Upgrade to $DBversion done ( Print notices message transport type )\n";
    SetVersion ($DBversion);
}

$DBversion = '4.00.00.006';
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
    $dbh -> do("ALTER TABLE borrowers ADD COLUMN disable_reading_history tinyint(1) default NULL;");
    $dbh -> do("ALTER TABLE borrowers ADD COLUMN amount_notify_date date;");
    $dbh -> do("ALTER TABLE deletedborrowers ADD COLUMN disable_reading_history tinyint(1) default NULL;");
    $dbh -> do("ALTER TABLE deletedborrowers ADD COLUMN amount_notify_date date;");

	print "Upgrade to $DBversion done ( Update borrowers table schema for reading history and amount notify date )\n";
    SetVersion ($DBversion);
}

$DBversion = '4.00.00.007';
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
    $dbh -> do("ALTER TABLE issuingrules ADD COLUMN max_fine decimal(28,6) default NULL;");
    $dbh -> do("ALTER TABLE issuingrules ADD COLUMN holdallowed tinyint(1) DEFAULT 2;");
    $dbh -> do("ALTER TABLE issuingrules ADD COLUMN max_holds int(4) default NULL;");

	print "Upgrade to $DBversion done ( Update issuingrules )\n";
    SetVersion ($DBversion);
}

$DBversion = '4.00.00.008';
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
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
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8;");
    $dbh -> do("
      CREATE TABLE import_profile_added_items (
        profile_id int(11) DEFAULT NULL,
        marcxml text COLLATE utf8_general_ci NOT NULL
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8;");
    $dbh -> do("
      CREATE TABLE import_profile_subfield_actions (
        profile_id int(11) NOT NULL DEFAULT '0',
        tag char(3) COLLATE utf8_general_ci NOT NULL DEFAULT '',
        subfield char(1) COLLATE utf8_general_ci NOT NULL DEFAULT '',
        action enum('add_always','add','delete') COLLATE utf8_general_ci DEFAULT NULL,
        contents varchar(255) COLLATE utf8_general_ci DEFAULT NULL,
        PRIMARY KEY (profile_id,tag,subfield),
        CONSTRAINT import_profile_subfield_actions_ibfk_1 FOREIGN KEY (profile_id) REFERENCES import_profiles (profile_id) ON DELETE CASCADE ON UPDATE CASCADE
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8;");

	print "Upgrade to $DBversion done ( Support for import profiles )\n";
    SetVersion ($DBversion);
}

$DBversion = '4.00.00.009';
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
    $dbh -> do("ALTER TABLE itemtypes ADD COLUMN reservefee decimal(28,6);");

	print "Upgrade to $DBversion done ( Accommodate reserve fee capability )\n";
    SetVersion ($DBversion);
}

$DBversion = '4.00.00.010';
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
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
        PRIMARY KEY  (branchcode,itemtype),
        CONSTRAINT overdueitemrules_ibfk_1 FOREIGN KEY (branchcode) REFERENCES branches (branchcode) ON DELETE CASCADE ON UPDATE CASCADE,
        CONSTRAINT overdueitemrules_ibfk_2 FOREIGN KEY (itemtype) REFERENCES itemtypes(itemtype) ON DELETE CASCADE ON UPDATE CASCADE
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8;");

	print "Upgrade to $DBversion done ( Overdue rules by itemtype )\n";
    SetVersion ($DBversion);
}

$DBversion = '4.00.00.011';
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
    $dbh -> do("
        CREATE TABLE itemdeletelist ( 
        list_id int(11) not null, 
        itemnumber int(11) not null, 
        biblionumber int(11) not null, 
        PRIMARY KEY (list_id,itemnumber)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8;");

	print "Upgrade to $DBversion done ( Batch item deletes )\n";
    SetVersion ($DBversion);
}

$DBversion = '4.00.00.012';
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
    $dbh -> do("
        CREATE TABLE itemstatus (
        statuscode_id int(11) NOT NULL auto_increment,
        statuscode varchar(10) NOT NULL default '',
        description varchar(25) default NULL,
        holdsallowed tinyint(1) NOT NULL default 0,
        holdsfilled tinyint(1) NOT NULL default 0,
        PRIMARY KEY  (statuscode_id),
        UNIQUE KEY statuscode (statuscode)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8;");
    $dbh -> do("INSERT INTO itemstatus (statuscode,description,holdsallowed,holdsfilled) VALUES ('','','0','0');");
    $dbh -> do("INSERT INTO itemstatus (statuscode,description,holdsallowed,holdsfilled) VALUES ('cat','Cataloging','1','1');");
    $dbh -> do("INSERT INTO itemstatus (statuscode,description,holdsallowed,holdsfilled) VALUES ('conya','Coming off New/YA','1','1');");
    $dbh -> do("INSERT INTO itemstatus (statuscode,description,holdsallowed,holdsfilled) VALUES ('cooj','Coming off O/J','1','1');");
    $dbh -> do("INSERT INTO itemstatus (statuscode,description,holdsallowed,holdsfilled) VALUES ('coryd','Coming Off R/Y Dot','1','1');");
    $dbh -> do("INSERT INTO itemstatus (statuscode,description,holdsallowed,holdsfilled) VALUES ('da','Display Area','1','1');");
    $dbh -> do("INSERT INTO itemstatus (statuscode,description,holdsallowed,holdsfilled) VALUES ('dc','YS Display','1','1');");
    $dbh -> do("INSERT INTO itemstatus (statuscode,description,holdsallowed,holdsfilled) VALUES ('mc','Media Cleaning','1','1');");
    $dbh -> do("INSERT INTO itemstatus (statuscode,description,holdsallowed,holdsfilled) VALUES ('n','Newly Acquired','1','1');");
    $dbh -> do("INSERT INTO itemstatus (statuscode,description,holdsallowed,holdsfilled) VALUES ('oflow','Overflow','1','1');");
    $dbh -> do("INSERT INTO itemstatus (statuscode,description,holdsallowed,holdsfilled) VALUES ('re','IN REPAIRS','1','1');");
    $dbh -> do("INSERT INTO itemstatus (statuscode,description,holdsallowed,holdsfilled) VALUES ('res','Reserved','1','0');");
    $dbh -> do("INSERT INTO itemstatus (statuscode,description,holdsallowed,holdsfilled) VALUES ('s','Shelving Cart','1','1');");
    $dbh -> do("INSERT INTO itemstatus (statuscode,description,holdsallowed,holdsfilled) VALUES ('scd','Senior Center Display','1','1');");
    $dbh -> do("INSERT INTO itemstatus (statuscode,description,holdsallowed,holdsfilled) VALUES ('st','Storage','0','0');");
    $dbh -> do("INSERT INTO itemstatus (statuscode,description,holdsallowed,holdsfilled) VALUES ('t','In Cataloging','1','1');");
    $dbh -> do("INSERT INTO itemstatus (statuscode,description,holdsallowed,holdsfilled) VALUES ('trace','Trace','1','1');");
    $dbh -> do("INSERT INTO itemstatus (statuscode,description,holdsallowed,holdsfilled) VALUES ('ufa','fast add item','1','0');");
    $dbh -> do("INSERT INTO itemstatus (statuscode,description,holdsallowed,holdsfilled) VALUES ('url','Online','0','0');");
    $dbh -> do("INSERT INTO itemstatus (statuscode,description,holdsallowed,holdsfilled) VALUES ('yso','YS Office','0','0');");

    $dbh -> do("ALTER TABLE items ADD COLUMN otherstatus varchar(10);");
    $dbh -> do("ALTER TABLE items ADD COLUMN suppress tinyint(1) NOT NULL DEFAULT 0 AFTER wthdrawn;");
    $dbh -> do("ALTER TABLE deleteditems ADD COLUMN otherstatus varchar(10);");
    $dbh -> do("ALTER TABLE deleteditems ADD COLUMN suppress tinyint(1) NOT NULL DEFAULT 0 AFTER wthdrawn;");

	print "Upgrade to $DBversion done ( Additional Item Statuses )\n";
    SetVersion ($DBversion);
}

$DBversion = '4.00.00.013';
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
    $dbh -> do("
        INSERT into authorised_values 
        (category,authorised_value, lib, imageurl) VALUES
        ('I_SUPPRESS',0,'Do not Suppress',''),
        ('I_SUPPRESS',1,'Suppress','');");

    # Altering MARC subfield structure for item suppression and other item status
    my $frames_sth = $dbh -> prepare("SELECT frameworkcode FROM biblio_framework");

    my $insert_sth = $dbh -> prepare("
        INSERT INTO marc_subfield_structure 
        (tagfield, tagsubfield, liblibrarian, libopac, repeatable, mandatory, kohafield, tab, authorised_value, authtypecode, value_builder, isurl, hidden, frameworkcode, seealso, link, defaultvalue) 
        VALUES ('952', 'i', 'Supressed','',0,0,'items.suppress',10,'I_SUPPRESS','','',0,0,?,NULL,'','');");

    my $insert_sth_2 = $dbh ->prepare("
        INSERT INTO marc_subfield_structure 
        (tagfield, tagsubfield, liblibrarian, libopac, repeatable, mandatory, kohafield, tab, authorised_value, authtypecode, value_builder, isurl, hidden, frameworkcode, seealso, link, defaultvalue) 
        VALUES ('952', 'k', 'Other item status', 'Other item status', 0, 0, 'items.otherstatus', 10, 'otherstatus', '', '', 0, 0, ?, NULL, '', '');");

    my $insert_sth_3 = $dbh ->prepare("
        INSERT INTO marc_subfield_structure (tagfield,tagsubfield,liblibrarian,libopac,repeatable,mandatory,kohafield,tab,authorised_value,isurl,hidden,frameworkcode) VALUES ('952','C','Permanent shelving location','Permanent shelving location',0,0,'items.permanent_location',10,'LOC',0,0,?);");

    $insert_sth -> execute("");
    $insert_sth_2 -> execute("");
    $insert_sth_3 -> execute("");
    $frames_sth->execute;
    while (my $frame = $frames_sth->fetchrow_hashref) {
        $insert_sth -> execute($frame->{frameworkcode});
        $insert_sth_2 -> execute($frame->{frameworkcode});
        $insert_sth_3 -> execute($frame->{frameworkcode});
    }

	print "Upgrade to $DBversion done ( Item suppression )\n";
    SetVersion ($DBversion);
}

$DBversion = '4.00.00.014';
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
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
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8;");
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
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8;");
    $dbh -> do("
        INSERT INTO clubsAndServicesArchetypes ( type,title,description,publicEnrollment,casData1Title,casData2Title,casData3Title,caseData1Title,caseData2Title,caseData3Title,casData1Desc,casData2Desc,casData3Desc,caseData1Desc,caseData2Desc,caseData3Desc   )
VALUES 
        ('club', 'Bestsellers Club', 'This club archetype gives the patrons the ability join a club for a given author and for staff to batch generate a holds list which shuffles the holds queue when specific titles or books by certain authors are received.', '0', 'Title', 'Author', 'Item Types', '', '', '', 'If filled in, the the club will only apply to books where the title matches this field. Must be identical to the MARC field mapped to title.', 'If filled in, the the club will only apply to books where the author matches this field. Must be identical to the MARC field mapped to author.', 'Put a list of space separated Item Types here for that this club should work for. Leave it blank for all item types.', '', '', '' ),
        ('service', 'New Items E-mail List', 'This club archetype gives the patrons the ability join a mailing list which will e-mail weekly lists of new items for the given itemtype and callnumber combination given.', 0, 'Itemtype', 'Callnumber', NULL, NULL, NULL, NULL, 'The Itemtype to be looked up. Use % for all itemtypes.', 'The callnumber to look up. Use % as wildcard.', NULL, NULL, NULL, NULL);");
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
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8;");

	print "Upgrade to $DBversion done ( Clubs and services )\n";
    SetVersion ($DBversion);
}

$DBversion = '4.01.00.000';
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
    $dbh->do("INSERT INTO systempreferences (variable,value,explanation,type) VALUES ('DisplayStafficonsXSLT','0',
        'If ON, displays the format, audience, type icons in the staff XSLT MARC21 result and display pages.','YesNo')");
    $dbh->do("INSERT INTO `systempreferences` (variable,value,options,explanation,type) VALUES ('CourseReserves','0','',
        'Turn ON Course Reserves functionality','YesNo');");
    $dbh -> do("INSERT INTO systempreferences (variable,value,explanation,options,type) VALUES ('Replica_DSN','',
        'DSN for reporting database replica','','Textarea');");
    $dbh -> do("INSERT INTO systempreferences (variable,value,explanation,options,type) VALUES ('Replica_user','',
        'Username for reporting database replica','','Textarea');");
    $dbh -> do("INSERT INTO systempreferences (variable,value,explanation,options,type) VALUES ('Replica_pass','',
        'Password for reporting database replica','','Textarea');");
    $dbh -> do("update systempreferences set options='itemtypes|ccode|none' where variable = 'OPACAdvancedSearchTypes';");
    $dbh -> do("update systempreferences set options='itemtypes|ccode|none' where variable = 'AdvancedSearchTypes';");

	print "Upgrade to $DBversion done ( Updating sysprefs )\n";
    SetVersion ($DBversion);
}

$DBversion = '4.01.00.001';
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
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
    $dbh->do("DROP TABLE IF EXISTS `instructor_course_link`;");
    $dbh->do("CREATE TABLE `instructor_course_link` (
        `instructor_course_link_id` INT(11) NOT NULL auto_increment,
        `course_id` INT(11) NOT NULL default 0,
        `instructor_borrowernumber` INT(11) NOT NULL default 0,
        PRIMARY KEY (`instructor_course_link_id`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8;");
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

    $dbh->do("INSERT INTO `authorised_values` ( category, authorised_value, lib ) values ( 'DEPARTMENT', 'Default', 'Default Department' );");
    $dbh->do("INSERT INTO `authorised_values` ( category, authorised_value, lib ) values ( 'TERM', 'Default', 'Default Term' );");
    $dbh->do("INSERT INTO permissions (module_bit,code,description) VALUES 
        ( 1, 'manage_courses', 'View, Create, Edit and Delete Courses'), 
        ( 1, 'put_coursereserves', 'Basic Course Reserves access,  user can put items on course reserve'), 
        ( 1, 'remove_coursereserves', 'Take items off course reserve'), 
        ( 1, 'checkout_via_proxy', 'Checkout via Proxy'), 
        ( 4, 'create_proxy_relationships', 'Create Proxy Relationships'), 
        ( 4, 'edit_proxy_relationships', 'Edit Proxy Relationships'), 
        ( 4, 'delete_proxy_relationships', 'Delete Proxy Relationships');");

	print "Upgrade to $DBversion done ( Support for course reserves )\n";
    SetVersion ($DBversion);
}

$DBversion = '4.01.00.002';
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
    $dbh->do("INSERT INTO `authorised_values` ( category, authorised_value, lib ) values ( 'LOST', '5', 'Claims Returned' );");

	print "Upgrade to $DBversion done ( Authorized value for 'claims returned' )\n";
    SetVersion ($DBversion);
}

$DBversion = '4.01.00.003';
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
    my $frames_sth = $dbh -> prepare("SELECT frameworkcode FROM biblio_framework");

    my $insert_sth = $dbh -> prepare("
        INSERT INTO marc_subfield_structure
        (tagfield, tagsubfield, liblibrarian, libopac, repeatable, mandatory, kohafield, tab, authorised_value, authtypecode, value_builder, isurl, hidden, frameworkcode, seealso, link, defaultvalue)
        VALUES ('658', 'a', 'Main curriculum objective', 'Main curriculum objective', 0, 0, '', 6, '', 'TOPIC_TERM', '', NULL, 0, ?, '', '', NULL);");
    my $insert_sth_2 = $dbh ->prepare("
        INSERT INTO marc_subfield_structure
        (tagfield, tagsubfield, liblibrarian, libopac, repeatable, mandatory, kohafield, tab, authorised_value, authtypecode, value_builder, isurl, hidden, frameworkcode, seealso, link, defaultvalue)
        VALUES ('658', 'b', 'Subordinate curriculum objective', 'Subordinate curriculum objective', 1, 0, '', 6, '', '', '', NULL, 0, ?, '', '', NULL);");
    my $insert_sth_3 = $dbh ->prepare("
        INSERT INTO marc_subfield_structure
  (tagfield, tagsubfield, liblibrarian, libopac, repeatable, mandatory, kohafield, tab, authorised_value, authtypecode, value_builder, isurl, hidden, frameworkcode, seealso, link, defaultvalue)
    VALUES ('658', 'c', 'Curriculum code', 'Curriculum code', 0, 0, '', 6, '', '', '', NULL, 0, ?, '', '', NULL);");
    my $insert_sth_4 = $dbh ->prepare("
        INSERT INTO marc_tag_structure (tagfield, liblibrarian,libopac,repeatable,mandatory,authorised_value,frameworkcode)
        VALUES ('658','SUBJECT--CURRICULUM OBJECTIVE','SUBJECT--CURRICULUM OBJECTIVE',1,0,NULL,?);");

    $frames_sth->execute;

    while (my $frame = $frames_sth->fetchrow_hashref) {
        $insert_sth -> execute($frame->{frameworkcode});
        $insert_sth_2 -> execute($frame->{frameworkcode});
        $insert_sth_3 -> execute($frame->{frameworkcode});
        $insert_sth_4 -> execute($frame->{frameworkcode});
    }

	print "Upgrade to $DBversion done ( Alter MARC subfield structure for curriculum indexing )\n";
    SetVersion ($DBversion);
}

$DBversion = '4.01.00.004';
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
    $dbh->do("DELETE FROM message_attributes WHERE message_attribute_id=3;");
    $dbh->do("DELETE FROM message_transports WHERE message_attribute_id=3;");
    $dbh->do("DELETE FROM letter WHERE code='EVENT' AND title='Upcoming Library Event';");

	print "Upgrade to $DBversion done ( Delete deprecated EVENT messages )\n";
    SetVersion ($DBversion);
}

$DBversion = '4.01.00.005';
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
    $dbh->do("ALTER TABLE authorised_values ADD opaclib varchar(80) default NULL;");

	print "Upgrade to $DBversion done ( Add OPAC descriptions to authorised_values )\n";
    SetVersion ($DBversion);
}

$DBversion = '4.01.00.006';
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
    $dbh->do(qq/
        CREATE TABLE `borrower_edits` (
        `id` int(11) NOT NULL auto_increment,
        `timestamp` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
        `borrowernumber` int(11) NOT NULL,
        `staffnumber` int(11) NOT NULL,
        `field` text NOT NULL,
        `before_value` mediumtext DEFAULT NULL,
        `after_value` mediumtext DEFAULT NULL,
        PRIMARY KEY (`id`),
        KEY `bnumber` (`borrowernumber`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8;/);
    
    $dbh->do("ALTER TABLE messages ADD COLUMN checkout_display tinyint(1) NOT NULL default 1;");
    $dbh->do("ALTER TABLE messages ADD COLUMN auth_value varchar(80) default NULL;");
    $dbh->do("ALTER TABLE messages ADD COLUMN staffnumber int(11) NOT NULL;");
	print "Upgrade to $DBversion done ( Patron edits tracking )\n";
    SetVersion ($DBversion);
}

$DBversion = '4.01.00.007';
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
    $dbh->do(qq/
        INSERT INTO `systempreferences` (variable,value,explanation,options,type)
        VALUES ('soundon','0','Enable to turn on circulation sounds. Not available on all browsers.','','YesNo');/); 

	print "Upgrade to $DBversion done ( add SoundOn syspref )\n";
    SetVersion ($DBversion);
}

$DBversion = '4.01.00.008';
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
    $dbh->do(qq/
        DELETE FROM `systempreferences` WHERE variable = 'KohaPTFSVersion';
    /); 

	print "Upgrade to $DBversion done ( Eliminate KohaPTFSVersion syspref )\n";
    SetVersion ($DBversion);
}

$DBversion = '4.01.00.009';
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
    $dbh->do(qq/
        CREATE INDEX s_lostcard ON statistics (borrowernumber, type);
    /); 
    $dbh->do(qq/
        CREATE INDEX idx_name ON borrowers (surname(4), firstname(4), othernames(4));
    /); 

	print "Upgrade to $DBversion done ( Index statistics and borrowers tables )\n";
    SetVersion ($DBversion);
}

$DBversion = '4.01.00.010';
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
    $dbh->do(qq/
        ALTER TABLE branches ADD COLUMN patronbarcodeprefix char(15);
    /); 
    $dbh->do(qq/
        ALTER TABLE branches ADD COLUMN itembarcodeprefix char(19);
    /); 
    $dbh->do(qq/
        INSERT INTO `systempreferences` (variable,value,explanation,options,type)
        VALUES ('patronbarcodelength','0','Length of branch-based cardnumber prefix','','Integer'),
        ('itembarcodelength','0','Length of branch-based item barcode prefix.','','Integer')
    /); 


	print "Upgrade to $DBversion done ( Add barcode prefix sysprefs and related columns to branches table )\n";
    SetVersion ($DBversion);
}

$DBversion = '4.01.00.011';
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {

    $dbh->do(qq/
        ALTER TABLE `subscription`
            ADD COLUMN `auto_summarize` BOOLEAN DEFAULT 1,
            ADD COLUMN `use_chron` BOOLEAN DEFAULT 1;
    /);

    my $frames_sth = $dbh -> prepare("SELECT frameworkcode FROM biblio_framework");

    my $insert_sth = $dbh -> prepare("
        INSERT INTO marc_subfield_structure
        (tagfield, tagsubfield, liblibrarian, libopac, repeatable, mandatory, kohafield, tab, authorised_value, authtypecode, value_builder, isurl, hidden, frameworkcode, seealso, link, defaultvalue)
        VALUES (?, '7', 'Branch Code','',0,0,'',8,'','','',0,5,?,NULL,'','');");

    my $insert_sth_2 = $dbh ->prepare("
        INSERT INTO marc_subfield_structure
        (tagfield, tagsubfield, liblibrarian, libopac, repeatable, mandatory, kohafield, tab, authorised_value, authtypecode, value_builder, isurl, hidden, frameworkcode, seealso, link, defaultvalue)
        VALUES (?, '9', 'subscription ID link','',0,0,'',8,'','','',0,5,?,NULL,'','');");

    $insert_sth -> execute('866',"");
    $insert_sth_2 -> execute('866',"");
    $insert_sth -> execute('867',"");
    $insert_sth_2 -> execute('867',"");
    $frames_sth->execute;
    while (my $frame = $frames_sth->fetchrow_hashref) {
        $insert_sth -> execute('866',$frame->{frameworkcode});
        $insert_sth_2 -> execute('866',$frame->{frameworkcode});
        $insert_sth -> execute('867',$frame->{frameworkcode});
        $insert_sth_2 -> execute('867',$frame->{frameworkcode});
    }
    print "Upgrade to $DBversion done ( Set up capability of automated serials summary holdings )\n";
    SetVersion ($DBversion);
}

$DBversion = '4.01.00.012';
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {

    $dbh->do(qq/
        ALTER TABLE `aqbudget` MODIFY COLUMN `aqbudgetid` int NOT NULL auto_increment;
    /);
    print "Upgrade to $DBversion done ( change way-too-small key on aqbudget to an int )\n";
    SetVersion ($DBversion);
}

$DBversion = '4.01.00.013';
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {

    $dbh->do(qq/
        ALTER TABLE `borrowers` ADD COLUMN `exclude_from_collection` BOOL NOT NULL DEFAULT FALSE;
    /);
    $dbh->do(qq/
        ALTER TABLE `deletedborrowers` ADD COLUMN `exclude_from_collection` BOOL NOT NULL DEFAULT FALSE;
    /);
    print "Upgrade to $DBversion done ( Add missing exclude_from_collection borrowers column )\n";
    SetVersion ($DBversion);
}


$DBversion = '4.01.00.014';
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {

    $dbh->do(qq/
        INSERT INTO `systempreferences` (variable,value,explanation,options,type)
        VALUES ('EnableClubsAndServices','1','Turn on the Clubs and Services module','','YesNo')
    /);
    print "Upgrade to $DBversion done ( Add system preference to enable/disable Clubs and Services )\n";
    SetVersion ($DBversion);
}

$DBversion = '4.01.00.015';
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
    $dbh->do(qq/
      CREATE TABLE IF NOT EXISTS `subscription_defaults` (
        `subscriptionid` int(11) NOT NULL,
        `dateaccessioned` date default NULL,
        `booksellerid` mediumtext,
        `homebranch` varchar(10) default NULL,
        `price` decimal(8,2) default NULL,
        `replacementprice` decimal(8,2) default NULL,
        `replacementpricedate` date default NULL,
        `datelastborrowed` date default NULL,
        `datelastseen` date default NULL,
        `stack` tinyint(1) default NULL,
        `notforloan` tinyint(1) NOT NULL default '0',
        `damaged` tinyint(1) NOT NULL default '0',
        `itemlost` tinyint(1) NOT NULL default '0',
        `wthdrawn` tinyint(1) NOT NULL default '0',
        `suppress` tinyint(1) NOT NULL default '0',
        `itemcallnumber` varchar(255) default NULL,
        `issues` smallint(6) default NULL,
        `renewals` smallint(6) default NULL,
        `reserves` smallint(6) default NULL,
        `restricted` tinyint(1) default NULL,
        `itemnotes` mediumtext,
        `holdingbranch` varchar(10) default NULL,
        `paidfor` mediumtext,
        `timestamp` timestamp NOT NULL default CURRENT_TIMESTAMP on update CURRENT_TIMESTAMP,
        `location` varchar(80) default NULL,
        `onloan` date default NULL,
        `cn_source` varchar(10) default NULL,
        `cn_sort` varchar(30) default NULL,
        `ccode` varchar(10) default NULL,
        `materials` varchar(10) default NULL,
        `uri` varchar(255) default NULL,
        `itype` varchar(10) default NULL,
        `more_subfields_xml` longtext,
        `enumchron` varchar(80) default NULL,
        `copynumber` varchar(32) default NULL,
        `permanent_location` varchar(80) default NULL,
        `otherstatus` varchar(10) default NULL,
        `coded_location_qualifier` varchar(25) NOT NULL,
        PRIMARY KEY  (`subscriptionid`)
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8;
    /);
    print "Upgrade to $DBversion done ( Creation of subscription_defaults table )\n";
    SetVersion ($DBversion);
}

$DBversion = '4.01.00.016';
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
    $dbh -> do("INSERT INTO letter (module,code,name,title,content) VALUES ('reserves','HOLD_CANCELED','Hold canceled','Hold canceled','The hold on the following item was canceled due to its removal from circulation.\r\n\r\n<<biblio.title>>\r\n\r\n');");

    print "Upgrade to $DBversion done ( Creation of default reserves/HOLD_CANCELED letter)\n";
    SetVersion ($DBversion);
}

$DBversion = '4.01.00.017';
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {

    $dbh->do(qq/
        ALTER TABLE `branches` ADD COLUMN `branchonshelfholds` tinyint(1) NOT NULL default 1;
    /);
    print "Upgrade to $DBversion done ( Add branchonshelfholds field to branches )\n";
    SetVersion ($DBversion);
}

$DBversion = '4.01.00.018';
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {

    $dbh->do(qq/
      INSERT INTO permissions (`module_bit`,`code`,`description`) VALUES ('9', 'relink_items', 'User can move an item from one bibliographic record to another.')
    /);
    print "Upgrade to $DBversion done ( Add permission relink_items  )\n";
    SetVersion ($DBversion);
}

# bug5562058, bug5535860, bug5535879 -hQ
$DBversion = '4.01.00.019';
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
   $dbh->do("ALTER TABLE reserves CHANGE expriationdate expirationdate date null");
   $dbh->do("ALTER TABLE serial CHANGE
      subscriptionid subscriptionid int(11) not null default 0");
   $dbh->do("ALTER TABLE subscriptionhistory CHANGE
      subscriptionid subscriptionid int(11) not null default 0");
   $dbh->do("ALTER TABLE subscriptionroutinglist CHANGE
      subscriptionid subscriptionid int(11) not null default 0");
   $dbh->do("ALTER TABLE subscription_defaults CHANGE
      subscriptionid subscriptionid int(11) not null default 0");
   $dbh->do("ALTER TABLE deletedborrowers CHANGE cardnumber cardnumber varchar(16) null");
   print "Upgrade to $DBversion done (expirationdate mispeling, subscriptionid and 
   cardnumber datatype )\n";
   SetVersion ($DBversion);
}

$DBversion = '4.01.10.000';
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {

    $dbh->do(qq/
        INSERT INTO `systempreferences` (variable,value,options,explanation,type) VALUES ('MaxShelfHoldsPerDay','3','','Maximum number of on-shelf holds each patron can place per day.','Integer');
    /);
    print "Upgrade to $DBversion done ( Add MaxShelfHoldsPerDay syspref )\n";
    SetVersion ($DBversion);
}

$DBversion = '4.03.00.000';
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {

    $dbh->do(qq/
        ALTER TABLE reserves ADD COLUMN displayexpired TINYINT(1) NOT NULL DEFAULT 1;
    /);
    $dbh->do(qq/
        ALTER TABLE old_reserves ADD COLUMN displayexpired TINYINT(1) NOT NULL DEFAULT 1;
    /);

	print "Upgrade to $DBversion done ( Add displayexpired column to the reserves and old_reserves tables )\n";
    SetVersion ($DBversion);
}

$DBversion = '4.03.00.001';
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
   $dbh->do(qq|ALTER TABLE labels_layouts ADD break_rule_string varchar(255) NOT NULL DEFAULT ''|);
   print "Upate to $DBversion done ( added labels_layouts.break_rule_string )\n";
   SetVersion ($DBversion);
}

$DBversion = '4.03.00.002';
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
    $dbh->do(qq/
      INSERT INTO message_attributes (message_attribute_id, message_name, takes_days) VALUES (7, 'Hold Cancelled', 0), (8, 'Hold Expired', 0);
    /);
    $dbh->do(qq/
      INSERT INTO message_transports (message_attribute_id, message_transport_type, is_digest, letter_module, letter_code) VALUES (7, 'email', 0, 'reserves', 'HOLD_CANCELLED'), (7, 'sms', 0, 'reserves', 'HOLD_CANCELLED'), (8, 'email', 0, 'reserves', 'HOLD_EXPIRED'), (8, 'sms', 0, 'reserves', 'HOLD_EXPIRED');
    /);
    $dbh->do(qq/
      UPDATE letter SET code='HOLD_CANCELLED',name='Hold Cancelled',title='Hold Cancelled' WHERE code='HOLD_CANCELED';
    /);
    $dbh->do(qq/
      INSERT INTO letter (module,code,name,title,content) VALUES ('reserves','HOLD_EXPIRED','Hold Expired','Hold Expired','The hold on the following item has expired.\r\n\r\n<<biblio.title>>\r\n\r\n');
    /);
   print "Upate to $DBversion done ( Inserted new message transports and attributes )\n";
   SetVersion ($DBversion);
}

$DBversion = '4.03.00.003';
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
    $dbh->do(qq/
        INSERT INTO `systempreferences` (variable,value,explanation,options,type) VALUES('NewPatronReadingHistory','enable','Set a default value regarding the retention of the reading history for a new patron','enable|disable','Choice');
    /);
    print "Upgrade to $DBversion done ( Add system preference to enable/disable reading history in patron creation)\n";
    SetVersion ($DBversion);
}

$DBversion = '4.03.00.004';
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
    $dbh->do("
    CREATE TABLE lost_items (
        id INT(11) NOT NULL auto_increment,
        borrowernumber INT(11) NOT NULL,
        itemnumber INT(11) NOT NULL,
        biblionumber INT(11) NOT NULL,
        barcode VARCHAR(20) DEFAULT NULL,
        homebranch VARCHAR(10) DEFAULT NULL,
        holdingbranch VARCHAR(10) DEFAULT NULL,
        itemcallnumber VARCHAR(100) DEFAULT NULL,
        itemnotes MEDIUMTEXT,
        location VARCHAR(80) DEFAULT NULL,
        itemtype VARCHAR(10) NOT NULL,
        title mediumtext,
        date_lost DATE NOT NULL,
        PRIMARY KEY (`id`),
        KEY (`borrowernumber`),
        KEY (`itemnumber`),
        KEY (`date_lost`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8;
    ");
    $dbh->do("INSERT INTO `systempreferences` (variable,value,explanation,options,type) VALUES('LinkLostItemsToPatron','0','If set, items marked lost will be listed in the patron Lost Items list','','YesNo')");
    $dbh->do("INSERT INTO `systempreferences` (variable,value,explanation,options,type) VALUES('RefundReturnedLostItem','0','If set, item charges will be refunded when a patron returns the item','','YesNo')");
    SetVersion ($DBversion);
    print "Upgrade to $DBversion done (Adding LostItems)\n";
}

$DBversion = '4.03.00.005';
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {

    $dbh->do(qq/
      INSERT INTO systempreferences (variable,value,options,explanation,type) VALUES (
        'FillRequestsAtPickupLibrary', '0', '', 'Fill hold requests at your local library if possible before sending an item to another branch to fill a hold request.', 'YesNo'
      )
    /);

    $dbh->do(qq/
      INSERT INTO systempreferences (variable,value,options,explanation,type) VALUES (
        'HoldsTransportationReductionThreshold', '1000000', '', 'The number of holds that must be in the queue for the holds transportation reduction to be enabled ( assuming FillRequestsAtPickupLibrary is enabled ).', 'Integer'
      )
    /);
    
    $dbh->do(qq/
      INSERT INTO systempreferences (variable,value,options,explanation,type) VALUES (
        'FillRequestsAtPickupLibraryAge', '30', '', 'Measured in days. If there are any higher-priority active holds that have been waiting longer than the FillRequestsAtPickupLibraryAge, then the item will fill the highest priority active hold, even thought that will require transportation. Note that the highest-priority hold may not be the one that’ s been waiting longest.', 'Integer'
      );
    /);
        
    print "Upgrade to $DBversion done ( Add systempreferences FillRequestsAtPickupLibrary, HoldsTransportationReductionThreshold, and FillRequestsAtPickupLibraryAge )\n";
}

$DBversion = '4.03.00.006';
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
    $dbh->do(qq/
      INSERT INTO `permissions` (`module_bit`, `code`, `description`) VALUES 
      ('4', 'lists', 'Create & Edit Borrower Lists'), 
      ('4', 'lists_bulk_modify', 'Modify All Accounts on a Borrower List'), 
      ('4', 'lists_bulk_delete', 'Delete Accounts on a Borrower Lists during a Bulk Modification');
    /); 

	print "Upgrade to $DBversion done ( Added permissions for Patron Lists )\n";
    SetVersion ($DBversion);
}

$DBversion = '4.03.00.007';
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {

    $dbh->do("INSERT INTO systempreferences (variable,value,explanation,options,type) VALUES('NextLibraryHoldsQueueWeight','0','Specify a list of library location codes separated by commas -- the list of codes will be traversed and weighted with first values given higher weight for holds fulfillment -- alternatively, if RandomizeHoldsQueueWeight is set, the list will be used in order. This preference overrides both StaticHoldsQueueWeight and RandomizeHoldsQueueWeight.',NULL,'TextArea')");

    print "Upgrade to $DBversion done ( Add new system preference NextLibraryHoldsQueueWeight )\n";
    SetVersion ($DBversion);
}

$DBversion = '4.03.00.008';
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
    $dbh->do(q|
        INSERT IGNORE INTO systempreferences (variable,value,options,explanation,type)
        VALUES ('UsePeriodicals', '0', '', 'Use newer "periodicals" module to manage serials.', 'YesNo')
        |);
    $dbh->do(q|DROP TABLE IF EXISTS periodicals|);
    $dbh->do(q|
        CREATE TABLE periodicals (
          id INT PRIMARY KEY AUTO_INCREMENT NOT NULL,
          biblionumber INT NOT NULL,
          iterator VARCHAR(48) NOT NULL,
          frequency VARCHAR(16) NOT NULL,
          sequence_format VARCHAR(64),
          chronology_format VARCHAR(64),
          FOREIGN KEY (`biblionumber`) REFERENCES biblio (`biblionumber`),
          UNIQUE (`biblionumber`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8
        |);
    $dbh->do(q|DROP TABLE IF EXISTS periodical_serials|);
    $dbh->do(q|
        CREATE TABLE periodical_serials (
          id INT PRIMARY KEY AUTO_INCREMENT NOT NULL,
          periodical_id INT NOT NULL,
          sequence VARCHAR(16),
          vintage VARCHAR(64) NOT NULL,
          publication_date DATE NOT NULL,
          FOREIGN KEY (`periodical_id`) REFERENCES periodicals (`id`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8
        |);
    $dbh->do(q|DROP TABLE IF EXISTS subscriptions|);
    $dbh->do(q|
        CREATE TABLE subscriptions (
          id INT PRIMARY KEY AUTO_INCREMENT NOT NULL,
          periodical_id INT NOT NULL,
          branchcode VARCHAR(10),
          aqbookseller_id INT,
          expiration_date DATE,
          opac_note TEXT DEFAULT NULL,
          staff_note TEXT DEFAULT NULL,
          adds_items BOOLEAN NOT NULL DEFAULT FALSE,
          item_defaults TEXT DEFAULT NULL,
          FOREIGN KEY (`periodical_id`) REFERENCES periodicals (`id`),
          FOREIGN KEY (`aqbookseller_id`) REFERENCES aqbooksellers (`id`),
          FOREIGN KEY (`branchcode`) REFERENCES branches (`branchcode`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8
        |);
    $dbh->do(q|DROP TABLE IF EXISTS subscription_serials|);
    $dbh->do(q|
        CREATE TABLE subscription_serials (
          id INT PRIMARY KEY AUTO_INCREMENT NOT NULL,
          subscription_id INT NOT NULL,
          periodical_serial_id INT NOT NULL,
          status INT NOT NULL DEFAULT 1,
          expected_date DATE,
          received_date DATETIME DEFAULT NULL,
          itemnumber INT,
          FOREIGN KEY (`subscription_id`) REFERENCES subscriptions (`id`),
          FOREIGN KEY (`periodical_serial_id`) REFERENCES periodical_serials (`id`),
          FOREIGN KEY (`itemnumber`) REFERENCES items (`itemnumber`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8;
        |);
    print "Upgrade to $DBversion done ( Add tables and syspref for periodicals. )\n";
    SetVersion ($DBversion);
}

$DBversion = '4.03.00.009';
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {

    $dbh->do("INSERT IGNORE INTO systempreferences (variable,value,explanation,options,type) VALUES ('ItemLocation','currentdesc','Library location for item','homedesc|homecode|currentdesc|currentcode|none','Choice')");

    print "Upgrade to $DBversion done ( Add new system preference ItemLocation )\n";
    SetVersion ($DBversion);
}

$DBversion = '4.03.00.010';
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {

    $dbh->do(q|
        CREATE TABLE IF NOT EXISTS `borrower_lists` (
            `list_id` int(11) NOT NULL auto_increment,
            `list_name` varchar(100) NOT NULL,
            `list_owner` int(11) NOT NULL,
            PRIMARY KEY  (`list_id`),
            UNIQUE KEY `list_name` (`list_name`,`list_owner`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8
        |);

    $dbh->do(q|
        CREATE TABLE `borrower_lists_tracking` (
            `list_id` int(11) NOT NULL,
            `borrowernumber` int(11) NOT NULL,
            PRIMARY KEY  (`list_id`,`borrowernumber`),
            KEY `list_id` (`list_id`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8
        |);

    print "Upgrade to $DBversion done ( Add tables for borrower_lists and borrower_lists_tracking)\n";
    SetVersion ($DBversion);
}

$DBversion = '4.03.02.000';
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {

    $dbh->do(q|ALTER TABLE `deletedborrowers` ADD COLUMN `exclude_from_collection` BOOL NOT NULL DEFAULT FALSE|);

    $dbh->do(q|ALTER TABLE `borrowers` ADD COLUMN `last_reported_date` date default NULL|);
    $dbh->do(q|ALTER TABLE `borrowers` ADD COLUMN `last_reported_amount` decimal(30,6) default NULL|);
    $dbh->do(q|ALTER TABLE `deletedborrowers` ADD COLUMN `last_reported_date` date default NULL|);
    $dbh->do(q|ALTER TABLE `deletedborrowers` ADD COLUMN `last_reported_amount` decimal(30,6) default NULL|);

    print "Upgrade to $DBversion done ( Correct the deletedborrowers table and sync schema for collections )\n";
    SetVersion ($DBversion);
}

$DBversion = '4.03.02.001';
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
    $dbh->do(q|CREATE INDEX owner_index ON virtualshelves(`owner`)|);
    print "Upgrade to $DBversion done ( Create owner index for virtualshelves )\n";
    SetVersion ($DBversion);
}

$DBversion = '4.03.02.002';
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {

    $dbh->do(qq/
      INSERT INTO systempreferences (variable,value,explanation,options,type) VALUES ('TalkingTechEnabled', '0', 'Turn on Talking Tech phone messaging','','YesNo');
    /);
    $dbh->do(qq/
      INSERT INTO `systempreferences` (variable,value,explanation,options,type) VALUES('TalkingTechFileName','\/tmp\/TtMESSAGE.csv','Set the file system path for the Talking Tech MESSAGE file','','free');
    /);
    $dbh->do("ALTER TABLE letter ADD ttcode VARCHAR(20) DEFAULT NULL");

    SetVersion ($DBversion);
    print "Upgrade to $DBversion done (Added TalkingTechEnabled and TalkingTechFileName system preferences. Added ttcode column to the letter table)\n";
}

$DBversion = '4.03.02.003';
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
    $dbh->do(q|CREATE INDEX object_index ON action_logs(`object`)|);
    print "Upgrade to $DBversion done ( Create object index for action_logs )\n";
}

$DBversion = '4.03.02.004';
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
    $dbh->do(q|
      ALTER TABLE `items`
      ADD         `checkinnotes` varchar(255) NULL
      AFTER       `itemnotes`
    |);
    $dbh->do(q|
      ALTER TABLE `deleteditems`
      ADD         `checkinnotes` varchar(255) NULL
      AFTER       `itemnotes`
    |);

    print "Upgrade to $DBversion done ( Added items.checkinnotes )\n";
    SetVersion ($DBversion);
}

$DBversion = '4.03.02.005';
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {

    $dbh->do(q|
      ALTER TABLE `authorised_values`
      ADD         `prefix` varchar(80) NULL
      AFTER       `authorised_value`
    |);
    $dbh->do(q|
      ALTER TABLE `labels_layouts`
      CHANGE `callnum_split` `callnum_split` varchar(8) NULL
    |);

    print "Upgrade to $DBversion done ( Added prefix for quick spine labels )\n";
    SetVersion ($DBversion);
}

$DBversion = '4.03.02.006';
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
    $dbh->do(q/
      INSERT INTO `systempreferences` (
         variable,
         value,
         explanation,
         options,
         type) VALUES (
      'EditAllLibraries',
      '1',
      'If set, all libraries have privileges to edit all items; if OFF, libraries may only edit items owned by their own library',
      '',
      'YesNo')
    /);

    $dbh->do(q|
      -- this is a lookup table
      CREATE TABLE `borrower_worklibrary` (
         borrowernumber int(11)     NOT NULL DEFAULT 0,
         branchcode     varchar(10) NOT NULL DEFAULT '',
         PRIMARY KEY (borrowernumber,branchcode),
         FOREIGN KEY (borrowernumber) REFERENCES borrowers(borrowernumber) ON DELETE CASCADE,
         FOREIGN KEY (branchcode)     REFERENCES branches(branchcode) ON DELETE CASCADE
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8;
    |);
    SetVersion ($DBversion);
    print "Upgrade to $DBversion done (Added table for items ownership)\n";
}

$DBversion = '4.03.03.000';
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
    SetVersion ($DBversion);
    print "Upgrade to $DBversion done ( Micro version update )\n";
}

$DBversion = '4.03.03.001';
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
    $dbh->do("INSERT INTO systempreferences (variable,value,explanation,options,type) VALUES ('RefundLostReturnedAmount','0','Refund a returned lost item rather than applying it to an outstanding balance','','YesNo')");

    $dbh->do(qq/
      INSERT INTO `permissions` (`module_bit`, `code`, `description`) VALUES 
      ('10', 'refund_charges', 'User can refund a charge');
    /);

    print "Upgrade to $DBversion done ( Add new system preference RefundLostReturnedAmount and a new granular permission to updatecharges module )\n";
    SetVersion ($DBversion);
}

$DBversion = '4.03.04.000';
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
    SetVersion ($DBversion);
    print "Upgrade to $DBversion done ( Micro version update )\n";
}

$DBversion = '4.03.04.001';
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
    $dbh->do("INSERT INTO systempreferences (variable,value,explanation,options,type) VALUES('ApplyMaxFineWhenLostItemChargeRefunded','1','Use with RefundReturnedLostItem. If set, the maxfine on an item will be applied automatically when the lost item charges are refunded after a patron returns the item','','YesNo')");

    print "Upgrade to $DBversion done ( Add new system preference ApplyMaxFineWhenLostItemChargeRefunded )\n";
    SetVersion ($DBversion);
}

$DBversion = '4.03.04.002';
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
    $dbh->do(q{
        ALTER TABLE tmp_holdsqueue ADD UNIQUE (`biblionumber`,`itemnumber`,`borrowernumber`)
    });

    print "Upgrade to $DBversion done ( Unique column index for tmp_holdsqueue )\n";
    SetVersion ($DBversion);
}

$DBversion = '4.03.05.000';
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
    SetVersion ($DBversion);
    print "Upgrade to $DBversion done ( Micro version update )\n";
}

$DBversion = '4.03.05.001';
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
    $dbh->do(q{
        CREATE TABLE `session_defaults` (
        `branchcode` varchar(10) NOT NULL,
        `name` varchar(32) NOT NULL,
        `key` varchar(32) NOT NULL,
        `value` text,
        PRIMARY KEY  (`branchcode`,`name`),
        CONSTRAINT `session_defaults_ibfk_1` FOREIGN KEY (`branchcode`) REFERENCES `branches` (`branchcode`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8
    });
    SetVersion ($DBversion);
    print "Upgrade to $DBversion done ( Add session_defaults table )\n";
}

$DBversion = '4.03.05.002';
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
    $dbh->do(q|DROP TABLE IF EXISTS hold_fill_targets|);
    $dbh->do(q|ALTER TABLE tmp_holdsqueue ADD queue_sofar text NOT NULL DEFAULT ''|);
    $dbh->do(q|ALTER TABLE tmp_holdsqueue CHANGE item_level_request 
      item_level_request tinyint(1) NOT NULL DEFAULT 0|);
    print "Upgrade to $DBversion done ( Tweak holds queue tables, drop hold_fill_targets )\n";
    SetVersion ($DBversion);
}

$DBversion = '4.03.05.003';
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
    $dbh->do(q|ALTER TABLE reserves_suspended ADD COLUMN
    displayexpired tinyint(1) NOT NULL DEFAULT 1|);
    
    SetVersion ($DBversion);
    print "Upgrade to $DBversion done ( Added reserves_suspended.displayexpired )\n";
}

$DBversion = '4.03.05.004';
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
    $dbh->do(q|ALTER TABLE categories ADD COLUMN
      maxholds smallint(6) default NULL AFTER reservefee|);
    $dbh->do(q|ALTER TABLE categories ADD COLUMN
       holds_block_threshold decimal(28,6) default NULL AFTER maxholds|);
    $dbh->do(q|ALTER TABLE categories ADD COLUMN
       circ_block_threshold decimal(28,6) default NULL AFTER holds_block_threshold|);
    
    SetVersion ($DBversion);
    print "Upgrade to $DBversion done ( Added columns to categories for max holds by patron category )\n";
}

$DBversion = '4.03.05.005';
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
    $dbh->do(q|INSERT IGNORE INTO systempreferences (variable,value,explanation,options,type) VALUES('HideItypeInOPAC','0','If ON, do not use/display item type in the OPAC','','YesNo');
    |);
    
    SetVersion ($DBversion);
    print "Upgrade to $DBversion done ( Added syspref HideItypeInOPAC )\n";
}

$DBversion = '4.03.06.000';
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
    SetVersion ($DBversion);
    print "Upgrade to $DBversion done ( Micro version update )\n";
}

$DBversion = '4.03.06.001';
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
    $dbh->do(q|ALTER TABLE itemtypes ADD COLUMN
    replacement_price DECIMAL(8,2) DEFAULT '0.00' AFTER rentalcharge|);

    SetVersion ($DBversion);
    print "Upgrade to $DBversion done ( Added itemtypes.replacement_price)\n";
}

$DBversion = '4.03.06.002';
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
    $dbh->do(q|TRUNCATE tmp_holdsqueue|);
    $dbh->do(q|ALTER TABLE tmp_holdsqueue ADD reservenumber int(11) 
      NOT NULL UNIQUE FIRST|);
    SetVersion ($DBversion);
    print "Upgrade to $DBversion done ( Add tmp_holdsqueue.reservenumber column )\n";
}

$DBversion = '4.03.07.000';
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
    SetVersion ($DBversion);
    print "Upgrade to $DBversion done ( Micro version update )\n";
}

$DBversion = '4.03.07.001';
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
    $dbh->do(q|INSERT IGNORE INTO systempreferences (variable,value,explanation,options,type) VALUES('EnableHoldExpiredNotice','0','If ON, allow hold expiration notices to be sent.','','YesNo')|);
    $dbh->do(q|INSERT IGNORE INTO systempreferences (variable,value,explanation,options,type) VALUES('EnableHoldCancelledNotice','0','If ON, allow hold cancellation notices to be sent.','','YesNo')|);

    SetVersion ($DBversion);
    print "Upgrade to $DBversion done ( Added syspref EnableHoldExpiredNotice and EnableHoldCancelledNotice )\n";
}

$DBversion = '4.03.08.000';
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
    SetVersion ($DBversion);
    print "Upgrade to $DBversion done ( Micro version update )\n";
}

$DBversion = '4.03.08.001';
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
    $dbh->do("INSERT INTO permissions (module_bit, code, description) VALUES ( 13, 'manage_csv_profiles', 'Manage CSV export profiles')");
    $dbh->do(q/
        CREATE TABLE `export_format` (
          `export_format_id` int(11) NOT NULL auto_increment,
          `profile` varchar(255) NOT NULL,
          `description` mediumtext NOT NULL,
          `marcfields` mediumtext NOT NULL,
          PRIMARY KEY  (`export_format_id`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8
    /);

    SetVersion ($DBversion);
    print "Upgrade to $DBversion done ( CSV Export profiles )\n";
}

$DBversion = '4.03.08.002';
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
    $dbh->do("ALTER TABLE items ADD catstat varchar(80) default NULL");
    $dbh->do("ALTER TABLE biblioitems ADD on_order_count varchar(80) default NULL, ADD in_process_count varchar(80) default NULL");
    $dbh->do("DELETE FROM authorised_values WHERE category='CATSTAT'");
    $dbh->do("INSERT INTO authorised_values (category,authorised_value,lib) VALUES ('CATSTAT','READY','Ready to be Cataloged')");
    $dbh->do("INSERT INTO authorised_values (category,authorised_value,lib) VALUES ('CATSTAT','BINDERY','Sent to Bindery')");
    $dbh->do("INSERT INTO authorised_values (category,authorised_value,lib) VALUES ('CATSTAT','CATALOGED','Cataloged')");
    $dbh->do("INSERT INTO `systempreferences` (variable,value,explanation,options,type) VALUES('GetItAcquisitions','0','If set, a link to GetIt Acquisitions will appear in the Koha menu and GetIt Acquisitions-specific functionality will appear elsewhere. Please refer to the documentation for details.','','YesNo')");
    $dbh->do("INSERT INTO `systempreferences` (variable,value,explanation,options,type) VALUES('BibliosCataloging','0','If set, a link to Biblios Cataloging will appear in the Koha menu and Biblios Cataloging-specific functionality will appear elsewhere. Please refer to the documentation for details.','','YesNo')");

    # Update Frameworks
    my $sth=$dbh->prepare("SELECT DISTINCT(frameworkcode) FROM marc_subfield_structure");
    $sth->execute;
    while (my $row=$sth->fetchrow_hashref) {
        my $frameworkcode = $row->{'frameworkcode'} || '';
        print "Adding CATSTAT to framework:$frameworkcode\n";
        $dbh->do("INSERT INTO `marc_subfield_structure`
                    (`tagfield`, `tagsubfield`, `liblibrarian`, `libopac`, `repeatable`, `mandatory`, `kohafield`, `tab`, `authorised_value`, `authtypecode`, `value_builder`, `isurl`, `hidden`, `frameworkcode`, `seealso`, `link`, `defaultvalue`)
            VALUES  ('952', 'k', 'Cataloging Status', 'Cataloging Status', 0, 0, 'items.catstat', 10, 'CATSTAT', '', '', NULL, 0, '$frameworkcode', '', '', NULL)");

        $dbh->do("INSERT INTO `marc_subfield_structure`
                    (`tagfield`, `tagsubfield`, `liblibrarian`, `libopac`, `repeatable`, `mandatory`, `kohafield`, `tab`, `authorised_value`, `authtypecode`, `value_builder`, `isurl`, `hidden`, `frameworkcode`, `seealso`, `link`, `defaultvalue`)
            VALUES  ('942', 't', 'On Order Count', 'On Order Count', 0, 0, 'biblioitems.on_order_count', 9, '', '', '', NULL, 0, '$frameworkcode', '', '', NULL)");

        $dbh->do("INSERT INTO `marc_subfield_structure`
                    (`tagfield`, `tagsubfield`, `liblibrarian`, `libopac`, `repeatable`, `mandatory`, `kohafield`, `tab`, `authorised_value`, `authtypecode`, `value_builder`, `isurl`, `hidden`, `frameworkcode`, `seealso`, `link`, `defaultvalue`)
            VALUES  ('942', 'u', 'In Processing Count', 'In Processing Count', 0, 0, 'biblioitems.in_process_count', 9, '', '', '', NULL, 0, '$frameworkcode', '', '', NULL)");

    }
    SetVersion ($DBversion);
    print "Upgrade to $DBversion done (Adds new item field 'CATSTAT' for maintaining cataloging status, adds on_order_count and in_process_count for GetIt integration, adds new system preferences for GetIt and Biblios menu display).\n";
}

$DBversion = '4.03.08.003';
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
    $dbh->do(q{INSERT IGNORE INTO systempreferences (variable,value,explanation,options,type) VALUES('BatchItemEditor','PTFS','Choose the preferred bulk item editor.','PTFS|Community','Choice')});

    SetVersion ($DBversion);
    print "Upgrade to $DBversion done ( Add syspref for choosing the bulk item editor )\n";
}

$DBversion = '4.03.08.004';
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
    $dbh->do(q|ALTER TABLE lost_items ADD claims_returned tinyint(1) NOT NULL DEFAULT 0|);

    SetVersion ($DBversion);
    print "Upgrade to $DBversion done ( Add lost_items.claims_returned )\n";
}

$DBversion = '4.03.08.005';
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
    $dbh->do(q{
        INSERT INTO permissions ( module_bit, code, description )
        VALUES
            ( 9, 'save_item_defaults', 'User may save a set of item defaults' ),
            ( 9, 'update_item_defaults', 'User may update a set of saved item defaults'),
            ( 9, 'delete_item_defaults', 'User may delete a set of saved item defaults')
    });

    SetVersion ($DBversion);
    print "Upgrade to $DBversion done ( Add permissions related to item session_defaults )\n";
}

$DBversion = '4.03.09.000';
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
    SetVersion ($DBversion);
    print "Upgrade to $DBversion done ( Micro version update )\n";
}

$DBversion = '4.03.09.001';
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
    $dbh->do(q|INSERT IGNORE INTO systempreferences (variable,value,explanation,options,type) VALUES('EnableHoldOnShelfNotice','0','If ON, allow hold awaiting pickup (holds shelf) notices to be sent.','','YesNo')|);

    SetVersion ($DBversion);
    print "Upgrade to $DBversion done ( Added syspref EnableHoldOnShelfNotice )\n";
}

$DBversion = '4.03.09.002';
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
    $dbh->do(q|INSERT IGNORE INTO systempreferences (variable,value,explanation,options,type) VALUES('ShowOPACAvailabilityFacetSearch','1','If ON, show the availability search option in the OPAC Refine your search.','','YesNo')|);

    SetVersion ($DBversion);
    print "Upgrade to $DBversion done ( Added syspref ShowOPACAvailabilityFacetSearch)\n";
}

$DBversion = '4.03.10.000';
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
    SetVersion ($DBversion);
    print "Upgrade to $DBversion done ( Micro version update )\n";
}

$DBversion = '4.03.10.001';
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
    $dbh->do(q{
        ALTER TABLE branches CHANGE branchip branchip TEXT DEFAULT NULL
    });

    SetVersion ($DBversion);
    print "Upgrade to $DBversion done ( Expand size of branches.branchip )\n";
}

$DBversion = '4.03.10.002';
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
    $dbh->do(q{
        CREATE TABLE IF NOT EXISTS `receipt_templates` (
          `module` varchar(20) NOT NULL default '',
          `code` varchar(20) NOT NULL default '',
          `branchcode` varchar(10) NOT NULL,
          `name` varchar(100) NOT NULL default '',
          `content` text,
          PRIMARY KEY  (`code`,`branchcode`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8
    });
    $dbh->do(q{
        CREATE TABLE IF NOT EXISTS `receipt_template_assignments` (
          `action` varchar(30) NOT NULL,
          `branchcode` varchar(10) NOT NULL,
          `code` varchar(20) default NULL,
          PRIMARY KEY  (`action`,`branchcode`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8
    });
    $dbh->do(q{
        INSERT INTO `systempreferences` (`variable` ,`value` ,`options` ,`explanation` ,`type`) VALUES
            ('UseReceiptTemplates', '0', '', 'Enable the use of the Receipt Templates system.', 'YesNo')
    });
    $dbh->do(q{
        INSERT INTO `permissions` (`module_bit`, `code`, `description`) VALUES 
            ('13', 'receipts_manage', 'Create, Edit & Delete Receipt Templates'), 
            ('13', 'receipts_assign', 'Assign Receipt Templates to Various Actions')
    });

    SetVersion ($DBversion);
    print "Upgrade to $DBversion done ( Add ReceiptTemplates)\n";
}

$DBversion = '4.03.10.003';
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
   $dbh->do(q{
      INSERT INTO `systempreferences` (variable,value,options,explanation,type) VALUES (
      'reservesNeedConfirmationOnCheckout',0,'','If ON, an item that can fill an item-level hold request requires confirmation to check out regardless whether the check out patron is the one who placed the hold or not','YesNo')
   });
   SetVersion ($DBversion);
   print "Upgrade to $DBversion done ( Added syspref reservesNeedConfirmationOnCheckout )\n";
}

$DBversion = '4.03.11.000';
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
    SetVersion ($DBversion);
    print "Upgrade to $DBversion done ( Micro version update )\n";
}

$DBversion = '4.03.11.001';
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
    $dbh->do(q{
        ALTER TABLE deleteditems
            ADD catstat varchar(80) default NULL
    });
    $dbh->do(q{
        ALTER TABLE deletedbiblioitems
            ADD on_order_count varchar(80) default NULL,
            ADD in_process_count varchar(80) default NULL
    });

    SetVersion ($DBversion);
    print "Upgrade to $DBversion done ( Sync deleteditems/deletedbiblioitems schema for changes made in 4.03.08.002 )\n";
}

$DBversion = '4.03.11.002';
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
    $dbh->do(q|INSERT IGNORE INTO systempreferences (variable,value,explanation,options,type) VALUES('OPACUseHoldType','0','If ON, allow OPAC users to place hold on specific items that are designated as item-level hold records.  Used in conjuction with OPACItemHolds.','','YesNo')|);
#    $dbh->do(q{
#        ALTER TABLE biblio
#            ADD `holdtype` ENUM('item','title','itemtitle') NOT NULL DEFAULT 'itemtitle'
#    });
    # Altering MARC subfield structure for biblio holdtype
    my $frames_sth = $dbh->prepare("SELECT frameworkcode FROM biblio_framework");

    my $insert_sth = $dbh->prepare("
        INSERT INTO marc_subfield_structure
        (tagfield, tagsubfield, liblibrarian, libopac, repeatable, mandatory, kohafield, tab, authorised_value, authtypecode, value_builder, isurl, hidden, frameworkcode, seealso, link, defaultvalue) 
        VALUES ('942', 'r', 'Hold Type','Hold Type',0,0,NULL,9,'HOLD_TYPE','','',0,0,?,NULL,'','itemtitle');");
    $insert_sth->execute('');
    $frames_sth->execute;
    while (my $frame = $frames_sth->fetchrow_hashref) {
        $insert_sth->execute($frame->{frameworkcode});
    }
    $dbh->do(q{
        INSERT INTO authorised_values
        (category,authorised_value,prefix,lib,opaclib,imageurl) VALUES
        ('HOLD_TYPE','item','','Item Hold','',''),
        ('HOLD_TYPE','title','','Title Hold','',''),
        ('HOLD_TYPE','itemtitle','','Item & Title Hold','','')
    });
#     $dbh->do("
#        UPDATE biblio SET holdtype='item' WHERE biblionumber IN
#          (SELECT biblionumber FROM subscription)
#    ");

    SetVersion ($DBversion);
    print "Upgrade to $DBversion done ( Added syspref OPACUseHoldType and biblio.holdtype )\n";
}

$DBversion = '4.03.11.003';
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
   $dbh->do(q{
      INSERT IGNORE INTO `systempreferences` (variable,value,options,explanation,type) VALUES (
      'UsePatronBranchForPatronInfo',0,'','If ON, the SIP patron information response (64) will use the patron branch rather than the institution ID in the AO field','YesNo')
   });
   SetVersion ($DBversion);
   print "Upgrade to $DBversion done ( Added syspref UsePatronBranchForPatronInfo )\n";
}

$DBversion = '4.03.11.004';
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
    $dbh->do(q|
        UPDATE systempreferences 
           SET explanation='Number of characters in system-wide barcode schema (patron cardnumbers)'
         WHERE variable   ='patronbarcodelength'
    |);
    $dbh->do(q|
        UPDATE systempreferences
           SET explanation='Number of characters in system-wide barcode schema (item barcodes)'
         WHERE variable   ='itembarcodelength'
    |);

    SetVersion ($DBversion);
    print "Upgrade to $DBversion done ( Sync sysprefs patronbarcodelength and itembarcodelength w/ explanations in koahstructure.sql )\n";
}

$DBversion = '4.03.12.000';
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
    SetVersion ($DBversion);
    print "Upgrade to $DBversion done ( Micro version update )\n";
}

$DBversion = '4.03.12.001';
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
    use C4::Reserves;

    foreach my $reservenumber (@{$dbh->selectcol_arrayref('SELECT reservenumber FROM reserves_suspended') // []}) {
        my $sth;
        my $query;

        $query = 'SELECT * FROM reserves_suspended WHERE reservenumber = ?';
        my $suspended_reserve = $dbh->selectrow_hashref( $query, undef, $reservenumber );

        $query = 'SELECT priority FROM reserves WHERE reservedate > ? AND biblionumber = ? ORDER BY reservedate ASC LIMIT 1';
        my $next_reserve = $dbh->selectrow_hashref( $query, undef, $suspended_reserve->{reservedate}, $suspended_reserve->{biblionumber} );

        my $new_priority = $next_reserve->{priority};
        if (!defined $new_priority) {
            my $res = $dbh->selectcol_arrayref(
                'SELECT priority FROM reserves WHERE biblionumber = ? ORDER BY priority DESC LIMIT 1',
                undef, $suspended_reserve->{biblionumber});
            $new_priority = ($res->[0] // 0);
        }
        $new_priority++;

        $query = 'INSERT INTO reserves SELECT * FROM reserves_suspended WHERE reservenumber = ?';
        $dbh->do( $query, undef, $reservenumber );
    
        $query = 'DELETE FROM reserves_suspended WHERE reservenumber = ?';
        $dbh->do( $query, undef, $reservenumber );

        $query = 'UPDATE reserves SET waitingdate = NULL, priority = ? WHERE reservenumber = ?';
        $dbh->do( $query, undef, $new_priority, $reservenumber );

        C4::Reserves::SuspendReserve($reservenumber, $suspended_reserve->{waitingdate});
    }

    $dbh->do('DROP TABLE reserves_suspended');

    SetVersion ($DBversion);
    print "Upgrade to $DBversion done ( Merge reserves_suspended entries back into reserves )\n";
}

$DBversion = '4.03.12.002';
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
   $dbh->do(q{
      INSERT IGNORE INTO `systempreferences` (variable,value,options,explanation,type) VALUES (
      'OPACXSLTResultsAvailabilityDisplay',1,'','If ON, the availability section of the OPAC results will display when OPACXLSTResultsDisplay is also ON','YesNo')
   });
   SetVersion ($DBversion);
   print "Upgrade to $DBversion done ( Added syspref OPACXSLTResultsAvailabilityDisplay )\n";
}

$DBversion = '4.03.13.000';
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
    SetVersion ($DBversion);
    print "Upgrade to $DBversion done ( Micro version update to $DBversion )\n";
}

$DBversion = '4.03.13.001';
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
    
    $dbh->do(q{
        ALTER TABLE reserves MODIFY reservedate DATETIME DEFAULT NULL
    });
    $dbh->do(q{
        ALTER TABLE old_reserves MODIFY reservedate DATETIME DEFAULT NULL
    });
    $dbh->do(q{
        ALTER TABLE reserveconstraints MODIFY reservedate DATETIME DEFAULT NULL
    });
    $dbh->do(q{
        ALTER TABLE tmp_holdsqueue MODIFY reservedate DATETIME DEFAULT NULL
    });
}

$DBversion = '4.03.13.002';
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
    $dbh->do("DELETE FROM systempreferences WHERE variable='holdCancelLength'");
    $dbh->do("INSERT INTO systempreferences VALUES(
      'HoldExpireLength',
      '30',
      NULL,
      'Specify how many days before a hold expires',
      'Integer'
    )");
    $dbh->do("DELETE FROM systempreferences WHERE LCASE(variable)='maxreserves'");
    $dbh->do("DELETE FROM systempreferences WHERE LCASE(variable)='noissuescharge'");
    $dbh->do("DELETE FROM systempreferences WHERE LCASE(variable)='maxoutstanding'");

    SetVersion ($DBversion);
    print "Upgrade to $DBversion done ( Changing reserves.reservedate et al to datetime; replace syspref holdCancelLength with HoldExpireLength; delete sysprefs maxreserves, noissuescharge, maxoutstanding )\n";
}

$DBversion = '4.03.14.000';
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
    SetVersion ($DBversion);
    print "Upgrade to $DBversion done ( Micro version update to $DBversion )\n";
}

$DBversion = '4.03.14.001';
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
    $dbh->do("
       UPDATE language_rfc4646_to_iso639 SET iso639_2_code='arm' WHERE rfc4646_subtag='hy'");
    $dbh->do("
       UPDATE language_rfc4646_to_iso639 SET iso639_2_code='eng' WHERE rfc4646_subtag='en'");
    $dbh->do("
       UPDATE language_rfc4646_to_iso639 SET iso639_2_code='fre' WHERE rfc4646_subtag='fr'");
    $dbh->do("
       UPDATE language_rfc4646_to_iso639 SET iso639_2_code='ita' WHERE rfc4646_subtag='it'");
    $dbh->do("
       INSERT INTO language_rfc4646_to_iso639 (rfc4646_subtag,iso639_2_code)
       VALUES
         ('fi','fin'),
         ('hmn','hmn'),
         ('lo','lao'),
         ('sr','srp'),
         ('tet','tet'),
         ('ur','urd')
    ");
    $dbh->do("
       INSERT INTO language_subtag_registry (subtag, type, description, added)
       VALUES
         ('hmn','language','Hmong',NOW()) ");
    $dbh->do("
       INSERT INTO language_descriptions (subtag, type, lang, description)
       VALUES
         ('hmn','language','en','Hmong'),
         ('hmn','language','hmn','Hmoob') ");

    SetVersion ($DBversion);
    print "Upgrade to $DBversion done ( Corrected ISO639-2 language codes )\n";
}

$DBversion = '4.03.15.000';
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
    SetVersion ($DBversion);
    print "Upgrade to $DBversion done ( Micro version update to $DBversion )\n";
}

$DBversion = '4.03.15.001';
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
   $dbh->do('ALTER TABLE itemtypes DROP notforhold');
   $dbh->do('ALTER TABLE itemtypes ADD notforhold tinyint(1) NOT NULL DEFAULT 0 
      AFTER reservefee');
   SetVersion ($DBversion);
   print "Upgrade to $DBversion done ( Corrected itemtypes.notforhold )\n";
}

$DBversion = '4.03.15.002';
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
   $dbh->do(q{
        INSERT INTO permissions (module_bit, code, description) VALUES
            (15, 'periodical_view', 'Basic periodicals permissions'),
            (15, 'periodical_create', 'Create a new periodical definition'),
            (15, 'periodical_edit', 'Modify a periodical definition'),
            (15, 'periodical_delete', 'Delete a periodical definition')
      });

   SetVersion ($DBversion);
   print "Upgrade to $DBversion done ( Add granular permissions for periodicals )\n";
}

$DBversion = '4.03.16.000';
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
    SetVersion ($DBversion);
    print "Upgrade to $DBversion done ( Micro version update to $DBversion )\n";
}

$DBversion = '4.03.16.001';
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
    $dbh->do("
       UPDATE language_rfc4646_to_iso639 SET iso639_2_code='por' WHERE rfc4646_subtag='pt'");

    SetVersion ($DBversion);
    print "Upgrade to $DBversion done ( Corrected ISO639-2 language codes )\n";
}

$DBversion = '4.03.16.002';
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
   $dbh->do("ALTER TABLE biblio DROP holdtype");
   $dbh->do("UPDATE marc_subfield_structure SET kohafield=NULL WHERE tagfield='942' AND tagsubfield='r'");
   $dbh->do("INSERT IGNORE INTO systempreferences (variable,value,explanation,options,type) VALUES ('DefaultOPACHoldType','title','If OPACUseHoldType is ON, this type will be used when a record is missing a 942\$r subfield','item|title|itemtitle','Choice')
   ");

   SetVersion ($DBversion);
   print "Upgrade to $DBversion done ( Added DefaultOPACHoldType syspref and removed biblio.holdtype column )\n";
}

$DBversion = '4.03.16.003';
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
    $dbh->do(q/
    INSERT INTO `systempreferences`
    (variable,value,options,explanation,type)
    VALUES('OPACShowActiveBranchFirstInResults','0','','If ON, in the OPAC, use the active library as the primary sort field for a record\'s holdings.  Used in conjunction with OPACDefaultItemSort where OPACDefaultItemSort is the secondary sort field.  Otherwise if Off, sort by OPACDefaultItemSort.','YesNo')/);
    $dbh->do(q/
    INSERT INTO `systempreferences` 
    (variable,value,options,explanation,type) 
    VALUES('OPACDefaultItemSort','itemtype','library|itemtype|location_description|itemcallnumber','Specify record holdings sort by what field in the OPAC.  Default is \'itemtype\'.','Choice')/);
    SetVersion ($DBversion);
    print "Upgrade to $DBversion done ( Added sysprefs OPACShowActiveBranchFirstInResults and OPACDefaultItemSort )\n";
}

$DBversion = '4.03.17.000';
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
    SetVersion ($DBversion);
    print "Upgrade to $DBversion done ( Micro version update to $DBversion )\n";
}

$DBversion = '4.03.17.001';
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
    $dbh->do(q{ALTER TABLE reserves DROP lowestPriority});
    $dbh->do(q{ALTER TABLE old_reserves DROP lowestPriority});

    SetVersion ($DBversion);
    print "Upgrade to $DBversion done ( Drop vestigial reserve.lowestPriority column )\n";
}

$DBversion = '4.03.17.002';
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
    $dbh->do(q/INSERT INTO `systempreferences` (variable,value,explanation,options,type) 
    VALUES('barcodeValidationRoutine','',
      'The type of barcode and routine against which barcodes will be checked for well-formed syntax.  Leave blank to allow any barcode string.','|codabar','Choice');
    /);
    SetVersion ($DBversion);
    print "Upgrade to $DBversion done ( Added syspref barcodeValidationRoutine )\n";
}

$DBversion = '4.03.17.003';
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
    $dbh->do(q/INSERT INTO `systempreferences` (variable,value,explanation,type) VALUES
        ('OPACShowCompletedHolds','7','The number in days that filled holds will display in the OPAC my hold history tab.  A value of 0 will display nothing.','Integer'),
        ('OPACShowCancelledHolds','7','The number in days that cancelled holds will display in the OPAC my hold history tab.  A value of 0 will display nothing.','Integer'),
        ('OPACShowExpiredHolds','7','The number in days that expired holds will display in the OPAC my hold history tab.  A value of 0 will display nothing.','Integer'),
        ('StaffShowCompletedHolds','7','The number in days that filled holds will display in the staff hold history tab.  A value of 0 will display nothing.','Integer'),
        ('StaffShowCancelledHolds','7','The number in days that cancelled holds will display in the staff hold history tab.  A value of 0 will display nothing.','Integer'),
        ('StaffShowExpiredHolds','7','The number in days that expired holds will display in the staff hold history tab.  A value of 0 will display nothing.','Integer'),
        ('AllowPatronsToCancelReadyHolds',0,'If ON, OPAC users will have the ability to cancel waiting holds','YesNo')
    /);

    SetVersion ($DBversion);
    print "Upgrade to $DBversion done ( Added holds display sysprefs )\n";
}

$DBversion = '4.03.18.000';
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
    SetVersion ($DBversion);
    print "Upgrade to $DBversion done ( Micro version update to $DBversion )\n";
}

$DBversion = '4.03.18.001';
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
    $dbh->do(q/INSERT INTO `systempreferences` (variable,value,explanation,options,type) VALUES
        ('SIPItemDisplay','barcode','This sets the SIP display for the item field in the patron information response message','barcode|barcode+title','Choice')
    /);

    SetVersion ($DBversion);
    print "Upgrade to $DBversion done ( Added SIPItemDisplay syspref )\n";
}

$DBversion = '4.03.18.002';
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
    SetVersion ($DBversion);
    $dbh->do(q{
    INSERT INTO `authorised_values` (`category`,`authorised_value`,`prefix`,`lib`,`imageurl`,`opaclib`) VALUES
        ('ETYPE','a',NULL,'Numeric data',NULL,NULL),
        ('ETYPE','b',NULL,'Computer program',NULL,NULL),
        ('ETYPE','c',NULL,'Representational',NULL,NULL),
        ('ETYPE','d',NULL,'Document',NULL,NULL),
        ('ETYPE','e',NULL,'Bibliographic data',NULL,NULL),
        ('ETYPE','f',NULL,'Font',NULL,NULL),
        ('ETYPE','g',NULL,'Video games',NULL,NULL),
        ('ETYPE','h',NULL,'Sounds',NULL,NULL),
        ('ETYPE','i',NULL,'Interactive multimedia',NULL,NULL),
        ('ETYPE','j',NULL,'Online system or service',NULL,NULL),
        ('ETYPE','m',NULL,'Combination',NULL,NULL),
        ('ETYPE','u',NULL,'Unknown',NULL,NULL),
        ('ETYPE','z',NULL,'Other',NULL,NULL)
    });

    print "Upgrade to $DBversion done ( Add authvals for facet searches )\n";
}

$DBversion = '4.03.19.000';
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
    SetVersion ($DBversion);
    print "Upgrade to $DBversion done ( Micro version update to $DBversion )\n";
}

$DBversion = '4.03.19.001';
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
    my $sth = $dbh->prepare('SHOW INDEXES IN tmp_holdsqueue');
    $sth->execute();
    my %seen = ();
    while(my $row = $sth->fetchrow_hashref()) {
       next if $seen{$$row{Key_name}};
       $seen{$$row{Key_name}}++;
       next unless $$row{Key_name} =~ /^biblionumber/;       
       $dbh->do("ALTER TABLE tmp_holdsqueue DROP KEY $$row{Key_name}");
    }
    $dbh->do("ALTER TABLE tmp_holdsqueue ADD CONSTRAINT UNIQUE KEY `biblionumber`
      (biblionumber,itemnumber,borrowernumber)");
    SetVersion ($DBversion);
    print "Upgrade to $DBversion done ( Normalize tmp_holdsqueue )\n";
}

$DBversion = '4.04.00.000';
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
    SetVersion ($DBversion);
    print "Upgrade to $DBversion done ( Minor version update to $DBversion )\n";
}

$DBversion = '4.05.00.000';
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
    SetVersion ($DBversion);
    print "Upgrade to $DBversion done ( Minor version update to $DBversion )\n";
}

$DBversion = '4.05.00.001';
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
   SetVersion ($DBversion);
   $dbh->do(q| 
      ALTER TABLE import_profiles ADD FOREIGN KEY (matcher_id) REFERENCES marc_matchers(matcher_id); 
   |);
   print "Upgrade to $DBversion done ( normalize import_profiles )\n";
}

$DBversion = '4.05.01.000';
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
    SetVersion ($DBversion);
    print "Upgrade to $DBversion done ( Minor version update to $DBversion )\n";
}

$DBversion = '4.05.01.001';
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
    $dbh->do(q{
        CREATE INDEX `typeindex` ON statistics (`type`)
    });
    SetVersion ($DBversion);
    print "Upgrade to $DBversion done ( Add column index for statistics.type )\n";
}

$DBversion = '4.05.01.002';
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
    $dbh->do(q{
        CREATE INDEX `borrowerindex` ON messages (`borrowernumber`)
    });
    $dbh->do(q{
        CREATE INDEX `cn_sortindex` ON items (`cn_sort`)
    });

    SetVersion ($DBversion);
    print "Upgrade to $DBversion done ( Add column index for messages.borrowernumber and items.cn_sort )\n";
}

$DBversion = '4.05.01.003';
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
    $dbh->do(q{
        INSERT INTO message_transport_types (message_transport_type) VALUES ('print_billing')
    });

    SetVersion ($DBversion);
    print "Upgrade to $DBversion done ( Add 'print_billing' message type )\n";
}

$DBversion = '4.05.03.000';
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
    SetVersion ($DBversion);
    print "Upgrade to $DBversion done ( Micro version update to $DBversion )\n";
}

$DBversion = '4.06.00.000';
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
    SetVersion ($DBversion);
    print "Upgrade to $DBversion done ( Minor version update to $DBversion )\n";
}

$DBversion = '4.07.00.000';
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
    SetVersion ($DBversion);
    print "Upgrade to $DBversion done ( Minor version update to $DBversion )\n";
}
$DBversion = '4.07.00.001';
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
    SetVersion ($DBversion);
    $dbh->do("DELETE FROM systempreferences WHERE variable = 'reservesNeedConfirmationOnCheckout'");
    $dbh->do("INSERT INTO systempreferences(variable,explanation,value,type) VALUES(?,?,?,?)",undef,
      'reservesNeedConfirmationOnCheckout',
      "Pipe-delimited list of types of prompts upon checkout with a hold pending: one or more of "
    . "'patronNotReservist_holdPending','patronNotReservist_holdWaiting','otherBibItem','noPrompts'.",
      'patronNotReservist_holdWaiting|otherBibItem',
      'free'
    );
    print "Upgrade to $DBversion done ( Modified systempreferences.reservesNeedConfirmationOnCheckout )\n";
}

$DBversion = '4.09.00.000';
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
    $dbh->do('ALTER TABLE lost_items change itemtype itemtype varchar(10) DEFAULT NULL');
    SetVersion ($DBversion);
    print "Upgrade to $DBversion done ( Allow lost_items.itemtype to be nullable )\n";
}

$DBversion = '4.09.00.002';
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
    # Altering MARC subfield structure for Other item and Cataloging status
    # Previous conflict with the 952$k field
    my $frames_sth = $dbh -> prepare("SELECT frameworkcode FROM biblio_framework");

    my $delete_sth = $dbh -> prepare("
        DELETE FROM marc_subfield_structure WHERE tagfield='952' AND tagsubfield='k';");

    my $insert_sth = $dbh ->prepare("
        INSERT INTO marc_subfield_structure
        (tagfield, tagsubfield, liblibrarian, libopac, repeatable, mandatory, kohafield, tab, authorised_value, authtypecode, value_builder, isurl, hidden, frameworkcode, seealso, link, defaultvalue) 
        VALUES ('952', 'k', 'Other item status', 'Other item status', 0, 0, 'items.otherstatus', 10, 'otherstatus', '', '', 0, 0, ?, NULL, '', '');");

    my $insert_sth_2 = $dbh ->prepare("
        INSERT INTO marc_subfield_structure
        (tagfield, tagsubfield, liblibrarian, libopac, repeatable, mandatory, kohafield, tab, authorised_value, authtypecode, value_builder, isurl, hidden, frameworkcode, seealso, link, defaultvalue) 
        VALUES ('952', 'K', 'Cataloging Status', 'Cataloging Status', 0, 0, 'items.catstat', 10, 'CATSTAT', '', '', NULL, 0, ?, '', '', NULL);");


    $delete_sth -> execute;
    $insert_sth -> execute("");
    $insert_sth_2 -> execute("");
    $frames_sth->execute;
    while (my $frame = $frames_sth->fetchrow_hashref) {
        $insert_sth -> execute($frame->{frameworkcode});
        $insert_sth_2 -> execute($frame->{frameworkcode});
    }

    print "Upgrade to $DBversion done ( Modify framework code )\n";
    SetVersion ($DBversion);
}

$DBversion = '4.09.00.003';
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
    $dbh->do('ALTER TABLE session_defaults DROP FOREIGN KEY `session_defaults_ibfk_1`');
    $dbh->do('ALTER TABLE session_defaults DROP PRIMARY KEY');
    $dbh->do('ALTER TABLE session_defaults ADD COLUMN session_defaults_id int(11) 
      PRIMARY KEY AUTO_INCREMENT FIRST');
    $dbh->do('ALTER TABLE session_defaults ADD CONSTRAINT `session_defaults_ibfk_1` 
      FOREIGN KEY (`branchcode`) REFERENCES `branches` (`branchcode`) ON UPDATE CASCADE ON DELETE CASCADE');

    SetVersion ($DBversion);
    print "Upgrade to $DBversion done ( Add session_defaults_id to sesstion defaults table and make it the primary key )\n";
}

$DBversion = '4.09.00.004';
if (C4::Context->preference('Version') < TransformToNum($DBversion)) {
    $dbh->do(q{UPDATE systempreferences SET options = ? WHERE variable LIKE ?}, undef,
         '|whitespace|trim|T-prefix|cuecat', 'itemBarcodeInputFilter');

    SetVersion ($DBversion);
    print "Upgrade to $DBversion done ( Add 'trim' barcode filter option )\n";
}

$DBversion = '4.09.00.005'; 
if (C4::Context->preference('Version') < TransformToNum($DBversion)) {
    my $sql = q{
        ALTER TABLE subscription_defaults
        ADD COLUMN catstat varchar(80) default NULL
    };
    $dbh->do($sql);

    SetVersion ($DBversion);
    print "Upgrade to $DBversion done ( added catstat to subscription_defaults table )\n";
}

$DBversion = '4.09.00.006';
if (C4::Context->preference("Version") < TransformToNum($DBversion)) {
    $dbh -> do("INSERT INTO letter (module,code,name,title,content) VALUES ('circulation','BILLING','Billing Notice','Billing Notice','Dear <<borrowers.firstname>> <<borrowers.surname>>,\n\nLibrary records show that you have an outstanding balance higher than library policy allows.  Please resolve these charges as soon as possible.  If your account is not paid, you may be referred to a collection agency within 30 days.  You may log in to your library account to verify how much you owe.\n\nPlease do not reply to this email message, it has been sent from an information only mailbox.\n\nThank you for your prompt attention to this matter.\n\n<<branches.branchname>> Staff\n');");

	print "Upgrade to $DBversion done ( Billing notice letter template )\n";
    SetVersion ($DBversion);
}

printf "Database schema now up to date at version %s as of %s.\n", $DBversion, scalar localtime;

=item DropAllForeignKeys($table)

  Drop all foreign keys of the table $table

=cut

sub DropAllForeignKeys {
    my ($table) = @_;
    # get the table description
    my $sth = $dbh->prepare("SHOW CREATE TABLE $table");
    $sth->execute;
    my $vsc_structure = $sth->fetchrow;
    # split on CONSTRAINT keyword
    my @fks = split(/CONSTRAINT /,$vsc_structure);
    # parse each entry
    foreach (@fks) {
        # isolate what is before FOREIGN KEY, if there is something, it's a foreign key to drop
        $_ = /(.*) FOREIGN KEY.*/;
        my $id = $1;
        if ($id) {
            # we have found 1 foreign, drop it
            $dbh->do("ALTER TABLE $table DROP FOREIGN KEY $id");
            $id="";
        }
    }
}


=item TransformToNum

  Transform the Koha version from a 4 parts string
  to a number, with just 1 .

=cut

sub TransformToNum {
    my $version = shift;
    # remove the 3 last . to have a Perl number
    $version =~ s/(.*\..*)\.(.*)\.(.*)/$1$2$3/;
    return $version;
}

=item SetVersion

    set the DBversion in the systempreferences

=cut

sub SetVersion {
    my $kohaversion = TransformToNum(shift);
    if (C4::Context->preference('Version')) {
      my $finish=$dbh->prepare("UPDATE systempreferences SET value=? WHERE variable='Version'");
      $finish->execute($kohaversion);
    } else {
      my $finish=$dbh->prepare("INSERT into systempreferences (variable,value,explanation) values ('Version',?,'The Koha database version. WARNING: Do not change this value manually, it is maintained by the webinstaller')");
      $finish->execute($kohaversion);
    }
}
exit;

