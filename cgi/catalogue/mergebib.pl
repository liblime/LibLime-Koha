#!/usr/bin/env perl

use warnings;
use strict;
use C4::Auth;
use C4::Biblio;
use C4::Context;
use C4::Output;
use CGI;

sub main {
    my $query = CGI->new;
    my $dbh   = C4::Context->dbh;
    my ($template, $loggedinuser, $cookie) = get_template_and_user(
        {
            script_name     => '/cgi-bin/koha/tools/mergebib.pl',
            template_name   => 'catalogue/mergebib.tmpl',
            query           => $query,
            type            => 'intranet',
            authnotrequired => 0,
            flagsrequired   => { editcatalogue => 'delete_bibliographic', editcatalogue => 'relink_items' },
        }
    );

    my $bib_merge_id   = $query->param('biblionumber');
    my $bib_save_id    = $query->param('bib_save_id');
    my $op             = $query->param('op');

    $op //= 0;

    unless ( $op > 0 && $op < 3 ) { # First time here?
        $template->param(get_lookup => 1);
    }

    my $bib_merge_title = get_generic('title', 'biblio', $bib_merge_id, $dbh, 1);
    $template->param(bib_merge_title => $bib_merge_title->[0]);
    $template->param(bib_merge_id    => $bib_merge_id);

    if ($op == 1) { # Lookup biblionumber to save.
        if ( $bib_save_id && $bib_save_id > 0 ) {
            my $bib_save_title = get_generic('title', 'biblio', $bib_save_id, $dbh, 1);
            $template->param(bib_save_id => $bib_save_id);
            $template->param(bib_save_title => $bib_save_title->[0]);

            if ($bib_save_title->[0]) {
                $template->param(get_lookup => 0);
                $template->param(confirm_merge => 1);
            }
            else {
                $template->param(NOTICE => 'Biblionumber not found');
                $template->param(get_lookup => 1);
                $template->param(confirm_merge => 0);
            }
        }
        else {
            $template->param(NOTICE => 'Please enter a biblionumber');
            $template->param(get_lookup => 1);
            $template->param(confirm_merge => 0);
        }
    }
    elsif ($op == 2) { # Do the merge.
        my $bib_merge_id = $query->param('bib_merge_id');

        if ( !is_deleted($bib_merge_id, $dbh) && $bib_save_id ) {
            my $error = my $ret = 0;
            my $message = undef;

            $ret = merge_items( $bib_save_id, $bib_merge_id, $dbh );
            ($message .= "Failed to merge items from $bib_merge_id to $bib_save_id. ") && (++$error) if $ret;

            $ret = merge_holds( $bib_save_id, $bib_merge_id, $dbh );
            ($message .= "Failed to merge holds from $bib_merge_id to $bib_save_id. ") && (++$error) if $ret;

            $ret = merge_generic('reviews', $bib_save_id, $bib_merge_id, $dbh);
            ($message .= "Failed to merge reviews from $bib_merge_id to $bib_save_id. ") && (++$error) if $ret;

            $ret = merge_generic('tags_all', $bib_save_id, $bib_merge_id, $dbh);
            ($message .= "Failed to merge tags from $bib_merge_id to $bib_save_id. ") && (++$error) if $ret;

            $ret = merge_generic('virtualshelfcontents', $bib_save_id, $bib_merge_id, $dbh);
            ($message .= "Failed to merge virtualshelfcontents from $bib_merge_id to $bib_save_id. ") && (++$error) if $ret;

            $ret = C4::Biblio::DelBiblio($bib_merge_id);
            ($message .= "Failed to delete biblio record: $bib_merge_id. ") && (++$error) if $ret;

            my $bib_save_title = get_generic('title', 'biblio', $bib_save_id, $dbh, 1);
            my $time = time; # So the UI updates.
            my $link = "<a href='/cgi-bin/koha/catalogue/detail.pl?biblionumber=$bib_save_id&amp;time=$time'>
                            $bib_save_title->[0]</a>";

            if ($error) {
                $message .= "Bibliographic merge process completed with errors: $link";
                $template->param(NOTICE => $message);
            }
            else {
                $template->param(NOTICE => "Bibliographic record merge complete: $link");
            }
        }
        else {
            $template->param(NOTICE => 'Invalid request: missing biblionumbers, please try again.');
            $template->param(get_lookup => 1);
            $template->param(confirm_merge => 0);
        }
    }

    output_html_with_http_headers($query, $cookie, $template->output);
}

sub merge_items {
    my ($bib_save_id, $bib_merge_id, $dbh) = @_;
    my $items_ref = get_generic('itemnumber', 'items', $bib_merge_id, $dbh, 2);
    my $biblioitemnumber = get_generic('biblioitemnumber', 'biblioitems', $bib_save_id, $dbh, 1);

    my $statement = 'UPDATE items SET biblionumber = ?, biblioitemnumber = ? WHERE itemnumber = ?';
    my $sth = $dbh->prepare($statement, undef) or return 1;
    my @bind = ($bib_save_id, $biblioitemnumber->[0], 0);

    for my $item (@$items_ref) {
        $bind[2] = $item->[0];
        $sth->execute(@bind) or return 1;
    }
    my $rows = $sth->rows;
    $rows ? return 0 : return 1;
}

sub merge_holds {
    my ($bib_save_id, $bib_merge_id, $dbh) = @_;

    # Update biblionumbers in reserves table.
    my $error = merge_generic('reserves', $bib_save_id, $bib_merge_id, $dbh);

    # Retrieve all reserve records and re-order priority.
    my $query = q{ SELECT reservenumber FROM reserves WHERE biblionumber = ?
                    AND (found IS NULL OR found = 'S') AND  priority > 0
                    ORDER BY priority ASC, timestamp DESC, reservedate ASC };
    my $res_ids = $dbh->selectall_arrayref( $query, undef, $bib_save_id );
    my $priority = 1;

    for my $id (@$res_ids) {
        $dbh->do('UPDATE reserves SET priority = ? WHERE reservenumber = ?', undef, $priority, $id->[0]) or return 1;
        $priority++;
    }

    $error ? return $error : return 0;
}

sub merge_generic {
    my ($table, $bib_save_id, $bib_merge_id, $dbh) = @_;
    my @bind = ($bib_save_id, $bib_merge_id);
    $dbh->do("UPDATE $table SET biblionumber = ? WHERE biblionumber = ?", undef, @bind) or return 1;
    return 0;
}

sub get_generic {
    my ($thing, $table, $biblionumber, $dbh, $count) = @_;
    my $query = "SELECT $thing FROM $table WHERE biblionumber = ?";
    ($count > 1) ?
        return $dbh->selectall_arrayref( $query, undef, $biblionumber ) :
        return $dbh->selectrow_arrayref( $query, undef, $biblionumber ) ;
}

sub is_deleted {
    my ($bibid, $dbh) = @_;
    my $query = 'SELECT COUNT(*) FROM biblio WHERE biblionumber = ?';
    my $return = $dbh->selectcol_arrayref( $query, undef, $bibid );
    return !$return->[0];
}

main();
