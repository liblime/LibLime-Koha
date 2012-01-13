INSERT INTO `authorised_values` ( category, authorised_value, lib ) values ( 'LOST','5','Trace' );
INSERT INTO `authorised_values` ( category, authorised_value, lib ) values ( 'DEPARTMENTS', 'Default', 'Default Department' );
INSERT INTO `authorised_values` ( category, authorised_value, lib ) values ( 'TERMS', 'Default', 'Default Term' );
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
    ('ETYPE','z',NULL,'Other',NULL,NULL);
INSERT into authorised_values (category,authorised_value, lib, imageurl) VALUES
    ('I_SUPPRESS',0,'Do not Suppress',''),
    ('I_SUPPRESS',1,'Suppress','');");
