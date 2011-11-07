package Koha::Schema::Callslip;

use strict;

use base qw(Koha::Schema::DB::Object::AutoBase1);

__PACKAGE__->meta->setup(
    table   => 'callslips',

    columns => [
        callslip_id                     => { type => 'serial', not_null => 1 },
        request_type                    => { type => 'enum', check_in => [ 'callslip', 'doc_del' ], default => 'callslip', not_null => 1 },
        borrowernumber                  => { type => 'integer', not_null => 1 },
        pickup_branch                   => { type => 'varchar', length => 10, not_null => 1 },
        request_status                  => { type => 'enum', check_in => [ 'requested', 'not_filled', 'in_process', 'in_transit', 'on_hold', 'completed', 'cancelled', 'expired' ], default => 'requested', not_null => 1 },
        request_time                    => { type => 'timestamp', not_null => 1 },
        not_needed_after                => { type => 'date' },
        no_fill_reason                  => { type => 'varchar', length => 50 },
        biblionumber                    => { type => 'integer', default => '0', not_null => 1 },
        requested_itemnumber            => { type => 'integer' },
        filled_itemnumber               => { type => 'integer' },
        opac_requested                  => { type => 'integer', default => '0', not_null => 1 },
        article_authors                 => { type => 'varchar', length => 255 },
        article_title                   => { type => 'varchar', length => 255 },
        issue_date                      => { type => 'varchar', length => 50 },
        article_pages                   => { type => 'varchar', length => 50 },
        chapter                         => { type => 'varchar', length => 50 },
        request_note                    => { type => 'varchar', length => 255 },
        reply_note                      => { type => 'varchar', length => 255 },
        requesting_staff_borrowernumber => { type => 'integer' },
        processing_staff_borrowernumber => { type => 'integer' },
        procesing_time                  => { type => 'datetime' },
        on_hold_staff_borrowernumber    => { type => 'integer' },
        keep_on_hold_time               => { type => 'datetime' },
        on_hold_expiration_time         => { type => 'datetime' },
        request_expiration_time         => { type => 'datetime' },
        cancellation_time               => { type => 'datetime' },
        cancelled_via_opac              => { type => 'integer', default => '0', not_null => 1 },
        completed_time                  => { type => 'datetime' },
    ],

    primary_key_columns => [ 'callslip_id' ],

    foreign_keys => [
        biblio => {
            class       => 'Koha::Schema::Biblio',
            key_columns => { biblionumber => 'biblionumber' },
        },

        borrower => {
            class       => 'Koha::Schema::Borrower',
            key_columns => { borrowernumber => 'borrowernumber' },
        },

        filled => {
            class       => 'Koha::Schema::Item',
            key_columns => { filled_itemnumber => 'itemnumber' },
        },

        requested => {
            class       => 'Koha::Schema::Item',
            key_columns => { requested_itemnumber => 'itemnumber' },
        },
    ],
);

1;

