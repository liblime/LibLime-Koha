#!/usr/bin/env perl

use strict;
use warnings;
use C4::Context;
use C4::Biblio;  # GetMarcBiblio GetXmlBiblio
use Getopt::Long;



my($counter,$filename,$homebranchfield,$homebranchsubfield,$branch,$strip_nonlocal_items,$start,$end);
my ($table,$want_help,$marcfile,$todate,$fromdate,$deleted,$onlyitems,$fromlast,$biblioonly);
my $itemtag="952";

GetOptions(
'h|help' => \$want_help,
'out=s' => \$marcfile,
'branch=s' => \$branch,
'start=s' => \$start,
'end=s' => \$end,
'table:s' => \$table,
"fromdate:s" => \$fromdate,
"todate:s" => \$todate,
"deleted" => \$deleted,
"last:s" => \$fromlast,
"biblio" => \$biblioonly,
);


if ($want_help){
	&usage();
	exit 0;
}
if(! $marcfile){	    
		&usage();
        die "Must specify output MARC file with -o option\n";
}
if ($todate){
	if (substr($todate,4,2) > "12" || substr($todate,6,2) > "32"){
		&usage();
        die "Date must be in YYYYMMDD format\n";
	}
	$todate = substr($todate,0,4)."-".substr($todate,4,2)."-".substr($todate,6,2)
}
if ($fromdate){
	if (substr($fromdate,4,2) > "12" || substr($fromdate,6,2) > "32"){
		&usage();
        die "Date must be in YYYYMMDD format\n";
	}
	$fromdate = substr($fromdate,0,4)."-".substr($fromdate,4,2)."-".substr($fromdate,6,2)
}

if ($fromlast){
	my $xlast = $fromlast;
	if ($xlast > 0 ){ $xlast = $xlast * -1};
	$todate = C4::Dates->new()->output('iso');
	$fromdate = C4::Dates->new() + C4::Dates->new(1,0,0,$xlast);
	$fromdate = substr($fromdate,0,4)."-".substr($fromdate,4,2)."-".substr($fromdate,6,2)
}


open OUT,">:utf8",$marcfile or die "Cannot open marc file $marcfile\n";

&report_header(); 

my $dbh=C4::Context->dbh;



$counter = 1;

my $item_cnt =0;
my $marc_cnt=0;
my $bad_cnt=0;
my @branch_arr;
my $split_cnt=0;
my $deleted_cnt;
my $err_cnt=0;
if ($branch){
	@branch_arr = split/\,/,$branch;
}
	my %bibs_to_export;
	my %deletedbibs_to_export;
	if ($deleted){
		&get_deleted_biblio();
	}else{
 		&get_updates();
 	}

    for my $biblionumber (sort keys %bibs_to_export) {
    	&process_bib($biblionumber);
    	print "$counter   $split_cnt\n" unless $counter % 1000;
		$counter++;
    }
    
    for my $biblionumber (sort keys %deletedbibs_to_export) {
    	&process_bib($biblionumber,1);
    	print "$counter   $split_cnt\n" unless $counter % 1000;
		$counter++;
		$deleted_cnt++;
    }
    
&report_footer(); 

################################################################################################
sub get_updates{
	my $query = "SELECT biblioitems.biblionumber from biblioitems,items where items.biblionumber=biblioitems.biblionumber ";
	if ($table){
     	$query ="SELECT DISTINCT biblioitems.biblionumber  FROM $table t,biblioitems,items WHERE t.biblionumber=biblioitems.biblionumber and biblioitems.biblionumber=items.biblionumber ";
     }
  
    if($start){
        $query .= "  AND biblioitems.biblionumber between $start and $end ";
    }
    if ($fromdate){
    	$query .= "  AND (items.timestamp >= '$fromdate'  or biblioitems.timestamp >= '$fromdate') ";
    }
    if ($todate){
    	$query .= "  AND (items.timestamp <= '$todate 99:99:99' or biblioitems.timestamp <= '$todate 99:99:99') ";
    }

    #print "$query\n";  

    my $sth = $dbh->prepare($query);
  
	my $cnt = 0 ;
    $sth->execute();
    while (my ($biblionumber) = $sth->fetchrow) {
    	$bibs_to_export{$biblionumber}=$biblionumber;
    	$cnt++;	
    }
   
    $sth->finish();
    
	$query = "SELECT biblioitems.biblionumber from biblioitems where biblioitems.biblionumber not in (select biblionumber from items where biblionumber =biblioitems.biblionumber)"; 
	
	if ($table){
		$query = "SELECT biblioitems.biblionumber from biblioitems,$table t where biblioitems.biblionumber=t.biblionumber and biblioitems.biblionumber not in (select biblionumber from items where biblionumber =biblioitems.biblionumber)"; 
	}
	
    if($start){
        $query .= "  AND biblioitems.biblionumber between $start and $end ";
    }
    if ($fromdate){
    	$query .= "  AND (biblioitems.timestamp >= '$fromdate') ";
    }
    if ($todate){
    	$query .= "  AND (biblioitems.timestamp <= '$todate 99:99:99') ";
   }
   # print "$query\n";  
 	
    $sth = $dbh->prepare($query);
	$sth->execute();
    while (my ($biblionumber) = $sth->fetchrow) {
    	$bibs_to_export{$biblionumber}=$biblionumber;
    	$cnt++;
    }
    $sth->finish();
	
	$query = "select deleteditems.biblionumber from deleteditems,biblioitems where deleteditems.biblionumber=biblioitems.biblionumber"; 
	
	if ($table){
		$query = "select deleteditems.biblionumber from deleteditems,biblioitems,$table t where deleteditems.biblionumber=t.biblionumber and deleteditems.biblionumber=biblioitems.biblionumber"; 
	}
	
    if($start){
        $query .= "  AND biblioitems.biblionumber between $start and $end ";
   }
    if ($fromdate){
    	$query .= "  AND (deleteditems.timestamp >= '$fromdate') ";
    }
    if ($todate){
    	$query .= "  AND (deleteditems.timestamp <= '$todate 99:99:99') ";
   }
  #  print "$query\n";  
 	
    $sth = $dbh->prepare($query);
	$sth->execute();
    while (my ($biblionumber) = $sth->fetchrow) {
    	$bibs_to_export{$biblionumber}=$biblionumber;
    	$cnt++;
    }
    $sth->finish();
	  
	 
}    
    
###############################################################################################
sub get_deleted_biblio{
	
	my $query = "SELECT deletedbiblioitems.biblionumber from deletedbiblioitems where biblionumber not in (select biblionumber from biblio where biblionumber= deletedbiblioitems.biblionumber)"; 
	
	if ($table){
		$query = "SELECT deletedbiblioitems.biblionumber,$table t from deletedbiblioitems.biblionumber=t.bilbionumber and deletedbiblioitems where deletedbiblioitems.biblionumber not in (select biblionumber from biblio where biblionumber= deletedbiblioitems.biblionumber)"; 
	}
    if($start){
        $query .= "  AND deletedbiblioitems between $start and $end ";
    }
    if ($fromdate){
    	$query .= "  AND (deletedbiblioitems.timestamp >= '$fromdate') ";
   }
    if ($todate){
    	$query .= "  AND (deletedbiblioitems.timestamp <= '$todate 99:99:99') ";
    }
   #  print "$query\n";  
    my $sth = $dbh->prepare($query);
	$sth->execute();
    while (my ($biblionumber) = $sth->fetchrow) {
   		$deletedbibs_to_export{$biblionumber}=$biblionumber;
    }
    $sth->finish(); 
}    


    
##################################################################################################
sub process_bib{
	my ($biblionumber,$deleted) =@_; 
    
		my $record ;
		if ($deleted){
			my $query = "select marcxml from deletedbiblioitems where biblionumber=? ";
			my $sth = $dbh->prepare($query);
			$sth->execute($biblionumber);
			my $record_xml = $sth->fetchrow;
    		$sth->finish();
    		eval{$record = MARC::Record->new_from_xml($record_xml,'UTF-8')};
			
		} else{   
        	$record = GetMarcBiblio($biblionumber);
		}
		
   		if (defined $record){
        	my $new_record = $record->clone;

			my $tmp_record = $new_record->as_usmarc();
			my $leader = $new_record->leader();
			my $pos5 = substr($leader,5,1);
			my $pos6 = substr($leader,6,1);
			my $pos7 = substr($leader,7,1);
			my $pos9 = substr($leader,9,1);
			my $mod=0;
			if ($deleted){
				$pos5 = "d";
				$mod=1;
			}
			if (not($pos5 =~ /^[a-z]$/)){
				$pos5 = "n";
				$mod=1;
			}
			if (not($pos6 =~ /^[a-z]$/)){
				$pos6 = "a";
				$mod=1;
			}
			if (not($pos7 =~ /^[ a-z]$/)  || ($mod && $pos7 eq " ")){
				$pos7 = "m";
				$mod=1;
			}
			if (not($pos9 =~ /^[ a]$/)){
				$pos9 = "a";
				$mod=1;
			}
			if ($mod){
				my $new_leader = substr($leader,0,5).$pos5.$pos6.$pos7." a".substr($leader,10,8)."a 4500";
				$new_record->leader($new_leader);
				$leader = $new_record->leader();
				$bad_cnt++;
			}
			my $new_record1;
			my $cnt=0;
			my $total_cnt=0;
			$new_record1 = $new_record->clone; 
			my $item_sth = $dbh->prepare("SELECT itemnumber,homebranch FROM items WHERE biblionumber = ?");
   			$item_sth->execute($biblionumber);
   			if (not $biblioonly){
   	 			while (my ($itemnumber,$homebranch) = $item_sth->fetchrow_array) {
    				if (defined $branch ){
    					my $found=0;
    					for (my $i=0;$i<@branch_arr;$i++){
    						if (defined $homebranch && $homebranch eq $branch_arr[$i]){$found=1}
   	 					}
    					if (not($found)){next}
    				}
        			my $marc_item = C4::Items::GetMarcItem($biblionumber, $itemnumber);
   	    	 		foreach my $item_field ($marc_item->field($itemtag)) {
    	        		$new_record1->insert_fields_ordered($item_field);
						$cnt ++;
						$item_cnt++;
						$total_cnt++;
						my $tmp_record = $new_record1->as_usmarc();
						my $new_leader = $new_record1->leader();
						if (substr($new_leader,0,5) > "85000"){
							print (OUT $new_record1->as_usmarc());
							$new_record1 = ();
							$new_record1 = $new_record->clone; 
							$cnt=0;
							$split_cnt++;
							$marc_cnt++;
						}
       		 		}
    					
				}
   			}
			
			if (($total_cnt>0 && $onlyitems) or (not $onlyitems) or $biblioonly){
				print (OUT $new_record1->as_usmarc());
				$marc_cnt++;
			}
        	
       	}else{
       		$err_cnt++;
       		printf("ERROR : %s\n",$biblionumber);
       	}
    }
    

######################################################################
sub usage{
 my $usage  = "\th|help\t\t-help \n";
	$usage .= "\tout\t\t-outfile (req) \n";
	$usage .= "\tbranch\t\t-all items with branch xx\n";
	$usage .= "\tstart\t\t-starting biblionumber\n";
	$usage .= "\tend\t\t-ending biblionumber\n";
	$usage .= "\ttable\t\t-name of table of biblionumbers\n";
	$usage .= "\tfromdate\t-from date yyyymmddd\n";
	$usage .= "\ttodate\t\t-to date yyyymmddd\n";
	$usage .= "\tdelete\t\t-Deleted biblio only\n";
	$usage .= "\tbiblioonly\t\t-Bibs only \n";
	$usage .= "\tlast\t\t-fromdate is today-last and todate is today\n";
	$usage .= "\nperl marcexport.pl -out out_file -all\n";
	print $usage;
}
######################################################################
sub report_header{
	my  $today = localtime();
	printf( "Exporting bibs/items starting %s\n",$today);
	printf ("Marc output file :  %s\n",$marcfile) if ($marcfile);
	printf ("Get the last %s days from today\n",$fromlast) if ($fromlast);
	printf ("All record modification from %s\n",$fromdate) if ($fromdate);
	printf ("All record modification to %s\n",$todate) if ($todate);
	printf ("Only deleted bibs \n") if ($deleted);
	printf ("Only bibs with items with the items attached \n") if ($onlyitems);
	printf ("Bibs only (no items)  \n") if ($biblioonly);
	
}
################################################################################
sub   report_footer  {
	if ($split_cnt){printf ("%s marc records where split \n",$split_cnt)}
	if ($deleted_cnt){printf ("%s deleted records \n",$deleted_cnt)}
	if ($err_cnt){printf ("%s ERROR records \n",$err_cnt)}
	print  $item_cnt . " items records exported\n";
	print  $marc_cnt . " marc records exported\n";
	print  $bad_cnt . " marc leaders changed\n" if ($bad_cnt);
	print "All done " . ( $counter - 1) . " records read \n";
	my $today = localtime();
	printf("finished Exporting Biblios /items  %s\n",$today); 
}
