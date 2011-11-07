#!/usr/bin/env perl

# Copyright 2000-2009 LibLime
#
# This file is part of Koha.
#
# Koha is free software; you can redistribute it and/or modify it under the
# terms of the GNU General Public License as published by the Free Software
# Foundation; either version 2 of the License, or (at your option) any later
# version.
#
# Koha is distributed in the hope that it will be useful, but WITHOUT ANY
# WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
# A PARTICULAR PURPOSE.  See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along with
# Koha; if not, write to the Free Software Foundation, Inc., 59 Temple Place,
# Suite 330, Boston, MA  02111-1307 USA


=head1 courses.pl

Script to manage a courses

=cut

use strict;

use CGI;
use Koha;
use C4::Context;
use C4::Auth;
use C4::Output;
use C4::Members;
use C4::Dates qw(format_date_in_iso);
use C4::Courses qw(CreateCourse UpdateCourse GetCourse GetCourses DeleteCourse LinkInstructor RemoveInstructor GetCourseReserves CreateCourseReserve DeleteCourseReserve GetInstructors);
use Date::Calc qw(Today Date_to_Days);
use C4::Branch qw(GetBranchName GetBranchesLoop);
use C4::Koha;
use C4::Items;

my $query = new CGI;
my $debug;

my $op = $query->param("op");
my $limit = $query->param("limit");
my $submit = $query->param("submit");
my $course_id = $query->param("course_id");
my $instructor_borrowernumber = $query->param("instructor_borrowernumber");
my $link_instructor = $query->param("link_instructor");
my ($template, $loggedinuser, $cookie)
    = get_template_and_user(
        {template_name => "circ/courses.tmpl",
           query => $query,
           type => "intranet",
           authnotrequired => 0,
           flagsrequired => {circulate => "put_coursereserves"},
           debug => ($debug) ? 1 : 0,
       });

# Courses CRUD
# Load the course from the course_id if loading the update form
my $course_hash;
if ($op and (($op eq 'update' and !$submit) or $op eq 'view_course_reserves' ) and $course_id) {
    $course_hash = GetCourse($course_id);
}
else {
    $course_hash = {
    course_id           => $query->param("course_id"),
    department          => $query->param("department"),
    course_number       => $query->param("course_number"),
    section             => $query->param("section"),
    course_name         => $query->param("course_name"),
    term                => $query->param("term"),
    staff_note          => $query->param("staff_note"),
    public_note         => $query->param("public_note"),
    students_count      => $query->param("students_count"),
    course_status       => $query->param("course_status"),
    };
}
my ($selected_department, $selected_term) = ($course_hash->{department},$course_hash->{term});
my $departments = GetAuthorisedValues('DEPARTMENT',$selected_department);
my $terms = GetAuthorisedValues('TERM',$selected_term);

if ($op and $op eq 'delete') {
	my $error = DeleteCourse($course_id);
    if ($error) {
        print $query->redirect("/cgi-bin/koha/circ/courses.pl?$error=1");
        exit;
    }
    else {
        print $query->redirect("/cgi-bin/koha/circ/courses.pl");
        exit;
    }
}
elsif ($op and $op eq 'create') {
    if ($submit) {
        $course_id = CreateCourse($course_hash);
        print $query->redirect("/cgi-bin/koha/circ/courses.pl?op=update&course_id=$course_id");
    }
}
elsif ($op and $op eq 'update') {
    if ($link_instructor) {
        LinkInstructor($course_id,$instructor_borrowernumber);
        print $query->redirect("/cgi-bin/koha/circ/courses.pl?op=update&course_id=$course_id");
    }
    elsif ($submit) {
        UpdateCourse($course_hash);
        print $query->redirect("/cgi-bin/koha/circ/courses.pl?op=view_course_reserves&course_id=$course_id");
    }
}
elsif ($op and $op eq 'remove_instructor') {
    RemoveInstructor($course_id,$instructor_borrowernumber);
    print $query->redirect("/cgi-bin/koha/circ/courses.pl?op=update&course_id=$course_id");
}
elsif ($op and $op eq 'delete_course_reserve') {
    my $course_reserve_id = $query->param("course_reserve_id");
    my $error = DeleteCourseReserve($course_reserve_id);
    if ($error) {
        print $query->redirect("/cgi-bin/koha/circ/courses.pl?op=view_course_reserves&course_id=$course_id&$error=1");
    }
    else {
        print $query->redirect("/cgi-bin/koha/circ/courses.pl?op=view_course_reserves&course_id=$course_id");
    }
}
elsif ($op and ( $op eq 'view_course_reserves' or $op eq 'create_course_reserve' ) ) {
    if ($submit) {
        my @barcodes = split(/\n/, $query->param('barcodes'));
        for my $barcode (@barcodes) {
            $barcode =~ s/\n|\r//g;
            my $itemnumber = GetItemnumberFromBarcode($barcode);
            if (!defined $itemnumber) {
                warn "Unable to find item for barcode '$barcode'";
                next;
            }

            my $course_reserve = {
                course_id => $course_id,
                itemnumber => $itemnumber,
                itemtype => $query->param('itemtype'),
                location => $query->param('location'),
                branchcode => $query->param('branchcode'),
                ccode => $query->param('ccode'),
                public_note => $query->param('public_note'),
                staff_note => $query->param('staff_note'),
            };
            CreateCourseReserve($course_reserve);
        }
        print $query->redirect("/cgi-bin/koha/circ/courses.pl?op=view_course_reserves&course_id=$course_id");
    }
    else {
    my $course = GetCourse($course_id);
    my $course_reserves = GetCourseReserves($course_id);
    my $branches = GetBranchesLoop();
    my $ccodes = GetAuthorisedValues('CCODE');
    my $locations = GetAuthorisedValues('LOC');
    my @itemtypes;
    my $koha_itemtypes = GetItemTypes();
    for my $itemtype ( sort {$koha_itemtypes->{$a}->{'description'} cmp $koha_itemtypes->{$b}->{'description'} } keys %$koha_itemtypes ) {
        push @itemtypes, { code => $itemtype, description => $koha_itemtypes->{$itemtype}->{'description'} };
    }

    $template->param(
        course_id           => $course->{"course_id"},
        department          => $course->{"department"},
        course_number       => $course->{"course_number"},
        section             => $course->{"section"},
        course_name         => $course->{"course_name"},
        term                => $course->{"term"},
        staff_note          => $course->{"staff_note"},
        public_note         => $course->{"public_note"},
        students_count      => $course->{"students_count"},
        course_status       => $course->{"course_status"},
        on_reserve_for_others => $course->{"on_reserve_for_others"},
        COURSE_RESERVES => $course_reserves,
        ITEMTYPES => \@itemtypes,
        CCODES => $ccodes,
        LOCATIONS => $locations,
        BRANCHES => $branches,
    );
    }
}
else {
    my $courses = GetCourses($limit);
	#for my $course (@$courses) {
	#}
    $template->param(COURSES => $courses);
}
if ($op and $op eq 'update') {
    $template->param(
    course_id           => $course_hash->{"course_id"},
    department          => $course_hash->{"department"},
    course_number       => $course_hash->{"course_number"},
    instructors         => $course_hash->{"instructors"},
    section             => $course_hash->{"section"},
    course_name         => $course_hash->{"course_name"},
    term                => $course_hash->{"term"},
    staff_note          => $course_hash->{"staff_note"},
    public_note         => $course_hash->{"public_note"},
    students_count      => $course_hash->{"students_count"},
    course_status       => $course_hash->{"course_status"},
    );
}
my $error_course_reserves_exist = 1 ? $query->param("ErrorCourseReservesExist") : undef;
my $error_item_lost = 1 ? $query->param("ErrorItemLost") : undef;
my $error_item_checkedout = 1 ? $query->param("ErrorItemCheckedOut") : undef;

$template->param(
    op => $op,
    ErrorCourseReservesExist => $error_course_reserves_exist,
    ErrorItemLost => $error_item_lost,
    ErrorItemCheckedOut => $error_item_checkedout,
    'create_update_form' => 1 ? ( $op eq 'create' || $op eq 'update' ) : undef,
    $op => 1,
    $course_hash->{"course_status"} => 1,
    instructors         => $course_hash->{"instructors"},
    TERMS => $terms,
    DEPARTMENTS => $departments
);
output_html_with_http_headers $query, $cookie, $template->output;
