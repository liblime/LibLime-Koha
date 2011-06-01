package C4::Courses;

# Copyright 2011 LibLime, a Division of PTFS, Inc.
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

use strict;
use warnings;
use C4::Context;
use C4::Members;
use C4::Koha;
use C4::Items;
use C4::Biblio;
use C4::Branch;

our ($VERSION,@ISA,@EXPORT,@EXPORT_OK,$debug);

BEGIN {
    $VERSION = 3.00;
    $debug = $ENV{DEBUG} || 0;
    require Exporter;
    @ISA = qw(Exporter);
    #Get data
    push @EXPORT, qw(
        &CreateCourse
        &UpdateCourse
        &DeleteCourse
        &GetCourses
        &GetCourse
        &GetCourseReservesForBiblio
        &GetInstructors
        &LinkInstructor
        &RemoveInstructor
        &GetCourseReserves
        &CreateCourseReserve
        &DeleteCourseReserve
    );

}

=head1 NAME

C4::Courses

=head1 SYNOPSIS

    use C4::Courses;

=head1 DESCRIPTION

=cut

sub CreateCourse {
    my ($course) = @_;
    my $dbh = C4::Context->dbh;
    # Create the course
    my $sth = $dbh->prepare("INSERT INTO courses (department,course_number,section,course_name,term,staff_note,public_note,students_count,course_status)
        VALUES (?,?,?,?,?,?,?,?,?)");
    $sth->execute($course->{department},$course->{course_number},$course->{section},$course->{course_name},$course->{term},$course->{staff_note},$course->{public_note},$course->{students_count},$course->{course_status});
    #$sth->finish;
    return $dbh->last_insert_id(undef,undef,undef,undef);
}

sub UpdateCourse {
    my ($course) = @_;
    my $dbh = C4::Context->dbh;

    # If being enabled, reinstate the item's location, etc., if being disabled, revert them
    my $course_reserves = GetCourseReserves($course->{course_id});
    if ($course->{course_status} eq 'enabled') {
        for my $cr (@$course_reserves) {
            my $course_reserve = GetCourseReserve($cr->{course_reserve_id});
            my $biblio = GetBiblioFromItemNumber($course_reserve->{itemnumber});
            ModItem({itype => $course_reserve->{itemtype}, ccode => $course_reserve->{ccode}, location => $course_reserve->{location}, holdingbranch => $course_reserve->{branchcode}, homebranch => $course_reserve->{branchcode} },$biblio->{biblionumber},$course_reserve->{itemnumber});
        }
    }
    elsif ($course->{course_status} eq 'disabled') {
        for my $course_reserve (@$course_reserves) {
            my $biblio = GetBiblioFromItemNumber($course_reserve->{itemnumber});
            ModItem({itype => $course_reserve->{original_itemtype}, ccode => $course_reserve->{original_ccode}, location => $course_reserve->{original_location}, holdingbranch => $course_reserve->{original_branchcode}, homebranch => $course_reserve->{original_branchcode} },$biblio->{biblionumber},$course_reserve->{itemnumber});
        }
    }

    # Update the course
    my $sth = $dbh->prepare("UPDATE courses SET department=?,course_number=?,section=?,course_name=?,term=?,staff_note=?,public_note=?,students_count=?,course_status=? WHERE course_id = ?");
    $sth->execute($course->{department},$course->{course_number},$course->{section},$course->{course_name},$course->{term},$course->{staff_note},$course->{public_note},$course->{students_count},$course->{course_status},$course->{course_id});
    $sth->finish;
    return;
}

sub DeleteCourse {
    my $course_id = shift;
    my $dbh = C4::Context->dbh;
    my $course_reserves = GetCourseReserves($course_id);
    if ($course_reserves) {
        return "ErrorCourseReservesExist";
    }
    my $sth = $dbh->prepare("DELETE FROM instructor_course_link WHERE course_id=?");
    $sth->execute($course_id);
    $sth->finish;
    my $sth2 = $dbh->prepare("DELETE FROM courses WHERE course_id=?");
    $sth2->execute($course_id);
    $sth2->finish;
}

sub GetCourses {
    my $limit = shift;
    my $dbh = C4::Context->dbh;
    my $query = "SELECT *,courses.course_id as course_id FROM courses";
    if ($limit) {
        $query.="
    LEFT JOIN instructor_course_link
        ON courses.course_id=instructor_course_link.course_id
    LEFT JOIN borrowers
        ON instructor_course_link.instructor_borrowernumber=borrowers.borrowernumber                 
    LEFT JOIN authorised_values
        ON courses.department=authorised_values.authorised_value
         WHERE
            department LIKE '$limit%' OR
            course_number LIKE '$limit%' OR
            section LIKE '$limit%' OR
            course_name LIKE '\%$limit%' OR
            term LIKE '$limit%' OR
            public_note LIKE '\%$limit%' OR
            CONCAT(surname,' ',firstname) LIKE '$limit%' OR
            CONCAT(firstname,' ',surname) LIKE '$limit%' OR
            lib LIKE '$limit%'
    GROUP BY courses.course_id
        "
    }
    $query .= " ORDER BY course_number, section";
    my $sth = $dbh->prepare($query);
    $sth->execute();
    my @courses;
    while (my $row = $sth->fetchrow_hashref) {
        $row->{instructors} = GetInstructors($row->{course_id});
        my $department = GetAuthorisedValue("DEPARTMENT",$row->{department});
        $row->{department_name} = $department->{'lib'};
        my $term = GetAuthorisedValue("TERM",$row->{term});
        $row->{term_name} = $term->{'lib'};
        $row->{course_disabled} = ($row->{course_status} eq 'disabled') ? 1 : undef;
        push @courses, $row;
    }
    return \@courses;
}

sub GetCourse {
    my $course_id = shift;
    my $dbh = C4::Context->dbh;
    my $sth = $dbh->prepare("SELECT * FROM courses WHERE course_id=?");
    $sth->execute($course_id);
    my $course_hash = $sth->fetchrow_hashref;
    my $instructors = GetInstructors($course_id);
    $course_hash->{instructors} = $instructors;
    $sth->finish;
    return $course_hash;
}

sub RemoveInstructor {
    my ($course_id, $instructor_borrowernumber) = @_;
    my $dbh = C4::Context->dbh;
    my $sth = $dbh->prepare("DELETE FROM instructor_course_link WHERE course_id=? AND instructor_borrowernumber=?");
    $sth->execute($course_id, $instructor_borrowernumber);
    $sth->finish;
}

sub LinkInstructor {
    my ($course_id,$instructor_borrowernumber) = @_;
    my $dbh = C4::Context->dbh;

    # Link this course to the instructor unless already linked
    my $sth = $dbh->prepare("SELECT * FROM instructor_course_link WHERE course_id=? AND instructor_borrowernumber=?");
    $sth->execute($course_id,$instructor_borrowernumber);
    my $result = $sth->fetchrow_hashref;
    unless ($result->{course_id}) {
        my $sth2 = $dbh->prepare("INSERT INTO instructor_course_link (course_id,instructor_borrowernumber) VALUES (?,?)");
        $sth2->execute($course_id,$instructor_borrowernumber);
        $sth2->finish;
    }
    $sth->finish;
}

sub GetCourseReserves {
    my $course_id = shift;
    my $dbh = C4::Context->dbh;
    my $sth = $dbh->prepare("SELECT * FROM course_reserves WHERE course_id=?");
    my $koha_itemtypes = GetItemTypes();
    my $ccodes = GetAuthorisedValues('CCODE');
    my $departments = GetAuthorisedValues('DEPARTMENT');

    $sth->execute($course_id);
    my @course_reserves;
    my $course_reserves_exist;
    my %biblist;
    while (my $row = $sth->fetchrow_hashref) {
        $course_reserves_exist++;
        my $on_reserve_count = GetCountOnReserveForItem($row->{itemnumber});
        my $item = GetItem($row->{'itemnumber'});
        if(!$item) {
            warn "Course $course_id has missing item $row->{itemnumber}\n";
            next;
        }
        $on_reserve_count -= 1 if $on_reserve_count and $on_reserve_count>0;
        $row->{on_reserve_for_others} = $on_reserve_count if $on_reserve_count;
        my $biblio = GetBiblioFromItemNumber($row->{itemnumber});
        # explicitly de-duplicate multiple items of the same bib
        next if (exists $biblist{$biblio->{biblionumber}});
        $biblist{$biblio->{biblionumber}} = 1;
        $row->{biblionumber} = $biblio->{biblionumber};
        my $itemtype = $row->{itemtype};
        my $department = GetAuthorisedValue("DEPARTMENT",$row->{department});
        my $ccode = GetAuthorisedValue("CCODE",$row->{ccode});
        my $shelving_location = GetAuthorisedValue("LOC",$row->{location});
        $row->{itemtype} = $koha_itemtypes->{$itemtype}->{'description'};
        $row->{itemcallnumber} = $item->{itemcallnumber};
        $row->{ccode} = $ccode->{lib};
        $row->{location} = $shelving_location->{lib};
        $row->{opac_location} = $shelving_location->{opaclib};
        $row->{department} = $department->{lib};
        my $record = GetMarcBiblio($biblio->{biblionumber});
        my $subtitle = $record->subfield('245', 'b') || '';
        $row->{title} = $biblio->{title} . " $subtitle";
        $row->{branchname} = GetBranchName($row->{branchcode}); # fixme: add branches hash, same for ccode and itemtype
        push @course_reserves, $row;
    }
    if ($course_reserves_exist) {
        return \@course_reserves;
    } else {
        return undef;
    }
}

sub GetCountOnReserveForItem {
    my $itemnumber = shift;
    my $dbh = C4::Context->dbh;
    my $sth = $dbh->prepare("SELECT COUNT(*) AS count FROM course_reserves WHERE itemnumber=?");
    $sth->execute($itemnumber);
    my $row = $sth->fetchrow_hashref;
    if ($row->{count} and $row->{count}>0) {
        return $row->{count};
    }
    else {
        return undef;
    }
}

sub GetCourseReserve {
    my $course_reserve_id = shift;
    my $dbh = C4::Context->dbh;
    my $sth = $dbh->prepare("SELECT * FROM course_reserves WHERE course_reserve_id=?");
    $sth->execute($course_reserve_id);
    my $course_reserve = $sth->fetchrow_hashref;
    return $course_reserve;
}

sub GetCourseReservesForBiblio {
    my ($biblionumber,$interface) = @_;
    my $course_reserves_exist;
    my $dbh = C4::Context->dbh;
    my $sth = $dbh->prepare("SELECT * FROM course_reserves
        LEFT JOIN items ON course_reserves.itemnumber=items.itemnumber
        LEFT JOIN biblio ON items.biblionumber=biblio.biblionumber
        WHERE biblio.biblionumber=? GROUP BY course_reserves.course_id");
    $sth->execute($biblionumber);
    my @course_reserves;
    while (my $row = $sth->fetchrow_hashref) {
        my $course = GetCourse($row->{course_id});
        if ($interface eq 'OPAC') {
            next if $course->{course_status} eq 'disabled';
        }
        $course_reserves_exist++;
        my $instructors;
        for my $instructor (@{$course->{instructors}}) {
            $instructors.=$instructor->{'firstname'}." ".$instructor->{'surname'}.";";
        }
        $instructors =~ s/;$/./;
        $row->{instructors} = $instructors;
        $row->{department} = $course->{department};
        my $department = GetAuthorisedValue("DEPARTMENT",$course->{department});
        $row->{department_opacdescription} = $department->{opaclib};
        $row->{department_description} = $department->{lib};
        $row->{course_number} = $course->{course_number};
        $row->{section} = $course->{section};
        $row->{course_name} = $course->{course_name};
        my $term = GetAuthorisedValue("TERM",$course->{term});
        $row->{term_opacdescription} = $term->{opaclib};
        $row->{term_description} = $term->{lib};
        $row->{public_note} = $course->{public_note};
        push @course_reserves, $row;
    }
    return (\@course_reserves,$course_reserves_exist);
}

sub CreateCourseReserve {
    my $course_reserve = shift;
    my $dbh = C4::Context->dbh;
    my $item = GetItem($course_reserve->{'itemnumber'});
    # Create this course reserve unless it already exists
    my $sth = $dbh->prepare("SELECT * FROM course_reserves WHERE course_id=? AND itemnumber=?");
    $sth->execute($course_reserve->{course_id},$course_reserve->{itemnumber});
    my $result = $sth->fetchrow_hashref;
    unless ($result->{course_id}) {
        $course_reserve->{ccode} = $item->{ccode} if $course_reserve->{ccode} eq 'NOCHANGE';
        $course_reserve->{location} = $item->{location} if $course_reserve->{location} eq 'NOCHANGE';
        $course_reserve->{branchcode} = $item->{homebranch} if $course_reserve->{branchcode} eq 'NOCHANGE';
        $course_reserve->{itemtype} = $item->{itype} if $course_reserve->{itemtype} eq 'NOCHANGE';
        my $sth2 = $dbh->prepare("INSERT INTO course_reserves (course_id,itemnumber,staff_note,public_note,itemtype,ccode,location,branchcode,original_itemtype,original_ccode,original_location,original_branchcode) VALUES (?,?,?,?,?,?,?,?,?,?,?,?)");
        $sth2->execute($course_reserve->{course_id},$course_reserve->{itemnumber},$course_reserve->{staff_note},$course_reserve->{public_note},$course_reserve->{itemtype},$course_reserve->{ccode},$course_reserve->{location},$course_reserve->{branchcode},$item->{itype},$item->{ccode},$item->{location},$item->{homebranch});
        $sth2->finish;
        # Modify the item with the specified item type, collection code and branch
        my $biblio = GetBiblioFromItemNumber($course_reserve->{itemnumber});
        ModItem({itype => $course_reserve->{itemtype}, ccode => $course_reserve->{ccode}, location => $course_reserve->{location}, holdingbranch => $course_reserve->{branchcode}, homebranch => $course_reserve->{branchcode} },$biblio->{biblionumber},$course_reserve->{itemnumber});
    }
}

sub DeleteCourseReserve {
    my $course_reserve_id = shift;
    my $dbh = C4::Context->dbh;

    # Revert the item using the old item type, collection code and branch
    my $course_reserve = GetCourseReserve($course_reserve_id);
    my $biblio = GetBiblioFromItemNumber($course_reserve->{itemnumber});
    my $item = GetItem($course_reserve->{itemnumber});
    if ($item->{'onloan'}){
        return "ErrorItemCheckedOut";
    }
    elsif ($item->{'itemlost'}){
        return "ErrorItemLost";
    }

    ModItem({itype => $course_reserve->{original_itemtype}, ccode => $course_reserve->{original_ccode},location => $course_reserve->{original_location}, holdingbranch => $course_reserve->{original_branchcode}, homebranch => $course_reserve->{original_branchcode} },$biblio->{biblionumber},$course_reserve->{itemnumber});

    my $sth = $dbh->prepare("DELETE FROM course_reserves WHERE course_reserve_id=?");
    $sth->execute($course_reserve_id);
    $sth->finish;
}

sub GetInstructors {
    my $course_id = shift;
    my $dbh = C4::Context->dbh;
    my $sth = $dbh->prepare("SELECT * FROM instructor_course_link WHERE course_id=?");
    $sth->execute($course_id);
    my @instructors;
    while (my $row = $sth->fetchrow_hashref) {
        my $borrower = GetMember ($row->{instructor_borrowernumber}, 'borrowernumber');
        push @instructors, $borrower if $borrower;
    }
    return \@instructors;
}

1;
