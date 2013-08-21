package C4::View::Member;

use strict;
use warnings;

use C4::Koha;
use C4::Biblio;
use C4::Reserves;
use C4::Circulation;
use C4::Dates qw(format_date);
use C4::Branch;
use C4::Members;
use C4::Accounts;
use C4::Items;

sub GetReservesLoop {
    my $borrowernumber = shift;

    my @borrowerreserv = GetReservesFromBorrowernumber($borrowernumber );
    my @reserveloop;
    foreach my $num_res (@borrowerreserv) {
        my %getreserv;
        my $getiteminfo  = GetBiblioFromItemNumber( $num_res->{'itemnumber'} );
        my $itemtypeinfo = getitemtypeinfo( $getiteminfo->{'itemtype'} );
        my ( $transfertwhen, $transfertfrom, $transfertto ) =
            GetTransfers( $num_res->{'itemnumber'} );

        foreach (qw(waiting transfered nottransfered)) {
            $getreserv{$_} = 0;
        }
        $getreserv{reservedate}  = $num_res->{'reservedate'};

        ## if sysprefs for expirationdate applies, there are two modes of
        ## expiration: first when the hold is placed, and then it is reset
        ## to a different expirationdate when it is Waiting on the holds shelf
        $getreserv{holdexpdate} = $num_res->{expirationdate}?
           format_date($num_res->{expirationdate}) : '';
        ## waitingdate is used for both an item waiting and suspended
        ## if suspended, it's the resumedate
        $getreserv{waitingdate} = $num_res->{waitingdate}?
           format_date($num_res->{waitingdate}) : '';
        $getreserv{suspended}   = (($num_res->{found} // '') eq 'S') ? 1 : 0;
        $getreserv{resumedate}  = ($getreserv{waitingdate} && $getreserv{suspended})?
           $getreserv{waitingdate} : '';
	     foreach (qw(biblionumber title author itemcallnumber itemnumber)) {
            $getreserv{$_} = $getiteminfo->{$_};
	     }
        $getreserv{barcodereserv}  = $getiteminfo->{'barcode'};
        $getreserv{itemtype}  = $itemtypeinfo->{'description'};

        # check if we have a waitin status for reservations
        if ( $num_res->{found} and $num_res->{'found'} eq 'W' ) {
            $getreserv{color}   = 'reserved';
            $getreserv{waiting} = 1;
        }

        # check transfers with the itemnumber foud in th reservation loop
        if ($transfertwhen) {
            $getreserv{color}      = 'transfered';
            $getreserv{transfered} = 1;
            $getreserv{datesent}   = C4::Dates->new($transfertwhen, 'iso')->output('syspref') or die "Cannot get new($transfertwhen, 'iso') from C4::Dates";
            $getreserv{frombranch} = GetBranchName($transfertfrom);
        }

        if ( (($getiteminfo->{holdingbranch} // '') ne $num_res->{branchcode})
             && !$transfertwhen ) {
            $getreserv{nottransfered} = 1;
            $getreserv{nottransferedby}
                = GetBranchName( $getiteminfo->{holdingbranch} );
        }

        # if we don't have a reserv on item, we put the biblio infos and the waiting position
        if ( ($getiteminfo->{title} // '') eq '' ) {
            my $getbibinfo = GetBiblioData( $num_res->{'biblionumber'} );
            my $getbibtype = getitemtypeinfo( $getbibinfo->{'itemtype'} );
            $getreserv{color}           = 'inwait';
            $getreserv{title}           = $getbibinfo->{'title'};
            $getreserv{nottransfered}   = 0;
            $getreserv{itemtype}        = $getbibtype->{'description'};
            $getreserv{author}          = $getbibinfo->{'author'};
            $getreserv{biblionumber}    = $num_res->{'biblionumber'};	
        }
        my $getbibinfo = GetBiblioData( $num_res->{'biblionumber'} );
        my $marc = MARC::Record->new_from_usmarc($getbibinfo->{'marc'});
        foreach my $subfield ( qw/b h n p/) {
          my $hashkey = "reserves_245" . $subfield;
          $getreserv{$hashkey} = $marc->subfield('245',$subfield)
            if (defined($marc->subfield('245',$subfield)));
        }
        $getreserv{reserves_260c} = $marc->subfield('260','c');
        if (defined($num_res->{'itemnumber'})) {
          my $item = GetItem($num_res->{'itemnumber'});
          $getreserv{callnumber} = $item->{'itemcallnumber'};
          $getreserv{enumchron}  = $item->{'enumchron'};
          $getreserv{copynumber} = $item->{'copynumber'};
        }
        $getreserv{pickupbranch} = C4::Branch::GetBranchName($num_res->{branchcode});
        $getreserv{waitingposition} = $num_res->{'priority'};
        $getreserv{reservenumber} = $num_res->{'reservenumber'};
        $getreserv{reservenotes} = $num_res->{reservenotes};
        push( @reserveloop, \%getreserv );
    }
    return \@reserveloop;
}

sub GetWaitingReservesLoop {
    my $borrowernumber = shift or return;
    my @reserves = GetReservesFromBorrowernumber($borrowernumber );

    @reserves = grep {$_->{found} ~~ 'W'} @reserves;
    return undef if (scalar @reserves == 0);

    foreach my $r (@reserves) {
        $r->{waiting} = 1;
        $r->{pickupbranch} = GetBranchName($r->{branchcode});
        my $biblio = C4::Biblio::GetBiblioData($r->{biblionumber});
        $r->{title} = $biblio->{title};
        $r->{author} = $biblio->{author};
        my $item = C4::Items::GetItem($r->{itemnumber});
        $r->{barcodereserv} = $item->{barcode};
    }

    return \@reserves;
}

sub GetRevisionsLoop {
    my $borrowernumber = shift;

    my $revisions = GetMemberRevisions($borrowernumber);
    my @revisionsloop;
    for my $revision (@$revisions) {
        my %row = %{ $revision };
        $row{staffnumber} = $revision->{user};
        $row{staffaction} = $revision->{action};
        push( @revisionsloop, \%row );
    }

    return \@revisionsloop;
}

sub GetIssuesLoop {
    my $borrowernumber = shift;
    my $params = shift;

    my $issue = GetPendingIssues($borrowernumber);
    my $issuecount = scalar(@$issue);
    my $today = POSIX::strftime('%Y-%m-%d', localtime);	# iso format
    my @issuedata;
    my $overdues_exist = 0;
    my $totalprice = 0;

    for ( my $i = 0 ; $i < $issuecount ; $i++ ) {
        my $datedue = $issue->[$i]{date_due};
        my $issuedate = $issue->[$i]{issuedate};
        $issue->[$i]{date_due}  = C4::Dates->new($issue->[$i]{date_due}, 'iso')->output('syspref');
        $issue->[$i]{issuedate} = C4::Dates->new($issue->[$i]{issuedate},'iso')->output('syspref');
        my $biblionumber = $issue->[$i]{biblionumber};
        my %row = %{ $issue->[$i] };
        if ($issue->[$i]{replacementprice} ) {
            $totalprice += $issue->[$i]{replacementprice};
        }
        $row{replacementprice} = $issue->[$i]{replacementprice};

        # item lost, damaged loops
        if ($row{itemlost}) {
            my $fw = GetFrameworkCode($issue->[$i]{biblionumber});
            my $category = GetAuthValCode('items.itemlost',$fw);
            my $lostdbh = C4::Context->dbh;
            my $sth = $lostdbh->prepare("select lib from authorised_values where category=? and authorised_value =? ");
            $sth->execute($category, $row{itemlost});
            my $loststat = $sth->fetchrow;
            if ($loststat) {
                $row{itemlost} = $loststat;
            }
        }
        if ($row{damaged}) {
            my $fw = GetFrameworkCode($issue->[$i]{biblionumber});
            my $category = GetAuthValCode('items.damaged',$fw);
            my $damageddbh = C4::Context->dbh;
            my $sth = $damageddbh->prepare("select lib from authorised_values where category=? and authorised_value =? ");
            $sth->execute($category, $row{damaged});
            my $damagedstat = $sth->fetchrow;
            if ($damagedstat) {
                $row{itemdamaged} = $damagedstat;
            }
        }
        # end lost, damaged
        if ( $datedue lt $today ) {
            $overdues_exist = 1;
            $row{red} = 1;
	}
        if ( $issuedate eq $today ) {
            $row{today} = 1; 
        }

        #find the charge for an item
        my ( $charge, $itemtype ) =
            GetIssuingCharges( $issue->[$i]{itemnumber}, $borrowernumber );

        my $itemtypeinfo = getitemtypeinfo($itemtype);
        $row{itemtype_description} = $itemtypeinfo->{description};
        $row{itemtype_image}       = $itemtypeinfo->{imageurl};
        $row{charge}               = sprintf( '%.2f', $charge );

        if ($row{renewals}) {
            ($row{renewals_intranet}, $row{renewals_opac})
                = GetRenewalDetails($row{itemnumber}, $borrowernumber);
        }

	my ($renewokay, $renewerror)
            = CanBookBeRenewed($borrowernumber, $issue->[$i]{itemnumber}, $params->{override_limit});
	$row{norenew} = !$renewokay;
	$row{can_confirm} = ( !$renewokay && $renewerror ne 'on_reserve' );
	$row{"norenew_reason_$renewerror"} = 1 if $renewerror;
	$row{renew_failed}  = $params->{renew_failed}{ $issue->[$i]{itemnumber} };
	$row{return_failed} = $params->{return_failed}{ $issue->[$i]{barcode} };
        $row{itemnotes} = $$issue[$i]{itemnotes} || '';
        if ($row{itemnotes} =~ /FASTADD RECORD/) {
            $row{itemnotes} = qq|<span style="color:red">$row{itemnotes}</span>|;
        }
        push( @issuedata, \%row );
    }
    return (\@issuedata, $totalprice, $overdues_exist);
}

sub GetTotalFines {
    my $borrowernumber = shift;
    return C4::Accounts::gettotalowed( $borrowernumber );
}

sub BuildFinesholdsissuesBox {
    my ($borrowernumber, $input) = @_;
    my %output;

    return {} if !defined $borrowernumber;

    ### reserves tab
    my $reserveloop = GetReservesLoop($borrowernumber);
    @output{qw(reservloop countreserv)} = ($reserveloop, scalar @$reserveloop);

    ### info edits tab
    $output{revisionloop} = GetRevisionsLoop($borrowernumber);

    ### issues tab
    my $override_limit = $input->param('override_limit') || 0;
    my @failedrenews = $input->param('failedrenew');
    my @failedreturns = $input->param('failedreturn');
    my %renew_failed;
    for my $renew (@failedrenews) { $renew_failed{$renew} = 1; }
    my %return_failed;
    for my $failedret (@failedreturns) { $return_failed{$failedret} = 1; }
    my ($issuedata, $totalprice, $overdues_exist)
        = GetIssuesLoop($borrowernumber,
                        {
                            override_limit => $override_limit,
                            renew_failed   => \%renew_failed,
                            return_failed  => \%return_failed,
                        });
    @output{qw(issueloop issuecount totalprice overdues_exist)}
        = ($issuedata, scalar @$issuedata, sprintf('%.2f', $totalprice), $overdues_exist);

    ### fines tab
    my $total = GetTotalFines($borrowernumber) // 0;
    @output{qw(totaldue totaldue_raw)} = (sprintf("%.2f", $total), $total);

    return \%output;
}

1;
