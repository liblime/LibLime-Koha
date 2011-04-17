package Koha::Schema::Itemtype;

use strict;

use base qw(Koha::Schema::DB::Object::AutoBase1);

__PACKAGE__->meta->setup(
    table   => 'itemtypes',

    columns => [
        itemtype          => { type => 'varchar', length => 10, not_null => 1 },
        description       => { type => 'scalar', length => 16777215 },
        renewalsallowed   => { type => 'integer' },
        rentalcharge      => { type => 'scalar', length => 64 },
        replacement_price => { type => 'numeric', default => '0.00', precision => 8, scale => 2 },
        notforloan        => { type => 'integer' },
        imageurl          => { type => 'varchar', length => 200 },
        summary           => { type => 'text', length => 65535 },
        reservefee        => { type => 'numeric', precision => 28, scale => 6 },
        notforhold        => { type => 'integer', default => '0', not_null => 1 },
    ],

    primary_key_columns => [ 'itemtype' ],

    relationships => [
        default_branch_item_rule => {
            class                => 'Koha::Schema::DefaultBranchItemRule',
            column_map           => { itemtype => 'itemtype' },
            type                 => 'one to one',
            with_column_triggers => '0',
        },

        summaries => {
            class      => 'Koha::Schema::Summary',
            column_map => { itemtype => 'itemtype' },
            type       => 'one to many',
        },
    ],
);

1;

