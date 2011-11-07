package Koha::Schema::Borrower;

use strict;

use base qw(Koha::Schema::DB::Object::AutoBase1);

__PACKAGE__->meta->setup(
    table   => 'borrowers',

    columns => [
        borrowernumber          => { type => 'serial', not_null => 1 },
        cardnumber              => { type => 'varchar', length => 16 },
        surname                 => { type => 'scalar', length => 16777215, not_null => 1 },
        firstname               => { type => 'text', length => 65535 },
        title                   => { type => 'scalar', length => 16777215 },
        othernames              => { type => 'scalar', length => 16777215 },
        initials                => { type => 'text', length => 65535 },
        streetnumber            => { type => 'varchar', length => 10 },
        streettype              => { type => 'varchar', length => 50 },
        address                 => { type => 'scalar', length => 16777215, not_null => 1 },
        address2                => { type => 'text', length => 65535 },
        city                    => { type => 'scalar', length => 16777215, not_null => 1 },
        zipcode                 => { type => 'varchar', length => 25 },
        country                 => { type => 'text', length => 65535 },
        email                   => { type => 'scalar', length => 16777215 },
        phone                   => { type => 'text', length => 65535 },
        mobile                  => { type => 'varchar', length => 50 },
        fax                     => { type => 'scalar', length => 16777215 },
        emailpro                => { type => 'text', length => 65535 },
        phonepro                => { type => 'text', length => 65535 },
        B_streetnumber          => { type => 'varchar', length => 10 },
        B_streettype            => { type => 'varchar', length => 50 },
        B_address               => { type => 'varchar', length => 100 },
        B_address2              => { type => 'text', length => 65535 },
        B_city                  => { type => 'scalar', length => 16777215 },
        B_zipcode               => { type => 'varchar', length => 25 },
        B_country               => { type => 'text', length => 65535 },
        B_email                 => { type => 'text', length => 65535 },
        B_phone                 => { type => 'scalar', length => 16777215 },
        dateofbirth             => { type => 'date' },
        branchcode              => { type => 'varchar', default => '', length => 10, not_null => 1 },
        categorycode            => { type => 'varchar', default => '', length => 10, not_null => 1 },
        dateenrolled            => { type => 'date' },
        dateexpiry              => { type => 'date' },
        gonenoaddress           => { type => 'integer' },
        lost                    => { type => 'integer' },
        debarred                => { type => 'integer' },
        contactname             => { type => 'scalar', length => 16777215 },
        contactfirstname        => { type => 'text', length => 65535 },
        contacttitle            => { type => 'text', length => 65535 },
        guarantorid             => { type => 'integer' },
        borrowernotes           => { type => 'scalar', length => 16777215 },
        relationship            => { type => 'varchar', length => 100 },
        ethnicity               => { type => 'varchar', length => 50 },
        ethnotes                => { type => 'varchar', length => 255 },
        sex                     => { type => 'varchar', length => 1 },
        password                => { type => 'varchar', length => 30 },
        flags                   => { type => 'integer' },
        userid                  => { type => 'varchar', length => 30 },
        opacnote                => { type => 'scalar', length => 16777215 },
        contactnote             => { type => 'varchar', length => 255 },
        sort1                   => { type => 'varchar', length => 80 },
        sort2                   => { type => 'varchar', length => 80 },
        altcontactfirstname     => { type => 'varchar', length => 255 },
        altcontactsurname       => { type => 'varchar', length => 255 },
        altcontactaddress1      => { type => 'varchar', length => 255 },
        altcontactaddress2      => { type => 'varchar', length => 255 },
        altcontactaddress3      => { type => 'varchar', length => 255 },
        altcontactzipcode       => { type => 'varchar', length => 50 },
        altcontactcountry       => { type => 'text', length => 65535 },
        altcontactphone         => { type => 'varchar', length => 50 },
        smsalertnumber          => { type => 'varchar', length => 50 },
        disable_reading_history => { type => 'integer' },
        amount_notify_date      => { type => 'date' },
        exclude_from_collection => { type => 'integer', default => '0', not_null => 1 },
        last_reported_date      => { type => 'date' },
        last_reported_amount    => { type => 'numeric', precision => 30, scale => 6 },
    ],

    primary_key_columns => [ 'borrowernumber' ],

    unique_key => [ 'cardnumber' ],

    foreign_keys => [
        category => {
            class       => 'Koha::Schema::Category',
            key_columns => { categorycode => 'categorycode' },
        },
    ],

    relationships => [
        biblios => {
            map_class => 'Koha::Schema::HoldFillTarget',
            map_from  => 'borrower',
            map_to    => 'biblio',
            type      => 'many to many',
        },

        borrower_message_preferences => {
            class      => 'Koha::Schema::BorrowerMessagePreference',
            column_map => { borrowernumber => 'borrowernumber' },
            type       => 'one to many',
        },

        borrower_worklibrary => {
            class      => 'Koha::Schema::BorrowerWorklibrary',
            column_map => { borrowernumber => 'borrowernumber' },
            type       => 'one to many',
        },

        borrowers => {
            map_class => 'Koha::Schema::ProxyRelationship',
            map_from  => 'proxy',
            map_to    => 'borrower',
            type      => 'many to many',
        },

        callslips => {
            class      => 'Koha::Schema::Callslip',
            column_map => { borrowernumber => 'borrowernumber' },
            type       => 'one to many',
        },

        fees => {
            class      => 'Koha::Schema::Fee',
            column_map => { borrowernumber => 'borrowernumber' },
            type       => 'one to many',
        },

        patroncards => {
            class      => 'Koha::Schema::Patroncard',
            column_map => { borrowernumber => 'borrowernumber' },
            type       => 'one to many',
        },

        patronimage => {
            class                => 'Koha::Schema::Patronimage',
            column_map           => { cardnumber => 'cardnumber' },
            type                 => 'one to one',
            with_column_triggers => '0',
        },

        payments => {
            class      => 'Koha::Schema::Payment',
            column_map => { borrowernumber => 'operator_id' },
            type       => 'one to many',
        },

        proxies => {
            map_class => 'Koha::Schema::ProxyRelationship',
            map_from  => 'borrower',
            map_to    => 'proxy',
            type      => 'many to many',
        },

        reserves => {
            class      => 'Koha::Schema::Reserve',
            column_map => { borrowernumber => 'borrowernumber' },
            type       => 'one to many',
        },

        summaries => {
            class      => 'Koha::Schema::Summary',
            column_map => { borrowernumber => 'created_by' },
            type       => 'one to many',
        },

        summaries_objs => {
            class      => 'Koha::Schema::Summary',
            column_map => { borrowernumber => 'last_modified_by' },
            type       => 'one to many',
        },

        tags_all => {
            class      => 'Koha::Schema::TagsAll',
            column_map => { borrowernumber => 'borrowernumber' },
            type       => 'one to many',
        },

        tags_approval => {
            class      => 'Koha::Schema::TagsApproval',
            column_map => { borrowernumber => 'approved_by' },
            type       => 'one to many',
        },
    ],
);

1;

