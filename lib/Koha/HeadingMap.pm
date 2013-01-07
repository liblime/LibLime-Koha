package Koha::HeadingMap;

sub bib_headings {
    return {
        '100' => { auth_type => 'PERSO_NAME',
                   subfields => 'abcdefghjklmnopqrst', main_entry => 1 },
        '110' => { auth_type => 'CORPO_NAME',
                   subfields => 'abcdefghklmnoprst', main_entry => 1 },
        '111' => { auth_type => 'MEETI_NAME',
                   subfields => 'acdefghjklnpqst', main_entry => 1 },
        '130' => { auth_type => 'UNIF_TITLE',
                   subfields => 'adfghklmnoprst', main_entry => 1 },
        '440' => { auth_type => 'UNIF_TITLE',
                   subfields => 'anp', series => 1 },
        '600' => { auth_type => 'PERSO_NAME',
                   subfields => 'abcdefghjklmnopqrstvxyz', subject => 1 },
        '610' => { auth_type => 'CORPO_NAME',
                   subfields => 'abcdefghklmnoprstvxyz', subject => 1 },
        '611' => { auth_type => 'MEETI_NAME',
                   subfields => 'acdefghjklnpqstvxyz', subject => 1 },
        '630' => { auth_type => 'UNIF_TITLE',
                   subfields => 'adfghklmnoprstvxyz', subject => 1 },
        '648' => { auth_type => 'CHRON_TERM',
                   subfields => 'avxyz', subject => 1 },
        '650' => { auth_type => 'TOPIC_TERM',
                   subfields => 'abvxyz', subject => 1 },
        '651' => { auth_type => 'GEOGR_NAME',
                   subfields => 'avxyz', subject => 1 },
        '655' => { auth_type => 'GENRE/FORM',
                   subfields => 'avxyz', subject => 1 },
        '700' => { auth_type => 'PERSO_NAME',
                   subfields => 'abcdefghjklmnopqrst' },
        '710' => { auth_type => 'CORPO_NAME',
                   subfields => 'abcdefghklmnoprst' },
        '711' => { auth_type => 'MEETI_NAME',
                   subfields => 'acdefghjklnpqst' },
        '730' => { auth_type => 'UNIF_TITLE',
                   subfields => 'adfghklmnoprst' },
        '800' => { auth_type => 'PERSO_NAME',
                   subfields => 'abcdefghjklmnopqrst', series => 1 },
        '810' => { auth_type => 'CORPO_NAME',
                   subfields => 'abcdefghklmnoprst', series => 1 },
        '811' => { auth_type => 'MEETI_NAME',
                   subfields => 'acdefghjklnpqst', series => 1 },
        '830' => { auth_type => 'UNIF_TITLE',
                   subfields => 'adfghklmnoprst', series => 1 },
    };
}

sub auth_types {
    return {
        100 => {
            authtypecode => 'PERSO_NAME',
            summary => 'Personal Name',
            authtypetext => 'Personal Name',
            auth_tag_to_report => '100',
        },
        110 => {
            authtypecode => 'CORPO_NAME',
            summary => 'Corporate Name',
            authtypetext => 'Corporate Name',
            auth_tag_to_report => '110',
        },
        111 => {
            authtypecode => 'MEETI_NAME',
            summary => 'Meeting Name',
            authtypetext => 'Meeting Name',
            auth_tag_to_report => '111',
        },
        130 => {
            authtypecode => 'UNIF_TITLE',
            summary => 'Uniform Title',
            authtypetext => 'Uniform Title',
            auth_tag_to_report => '130',
        },
        148 => {
            authtypecode => 'CHRON_TERM',
            summary => 'Chronological Term',
            authtypetext => 'Chronological Term',
            auth_tag_to_report => '148',
        },
        150 => {
            authtypecode => 'TOPIC_TERM',
            summary => 'Topical Term',
            authtypetext => 'Topical Term',
            auth_tag_to_report => '150',
        },
        151 => {
            authtypecode => 'GEOGR_NAME',
            summary => 'Geographic Name',
            authtypetext => 'Geographic Name',
            auth_tag_to_report => '151',
        },
        155 => {
            authtypecode => 'GENRE/FORM',
            summary => 'Genre/Form Term',
            authtypetext => 'Genre/Form Term',
            auth_tag_to_report => '155',
        },
    };
}

1;
