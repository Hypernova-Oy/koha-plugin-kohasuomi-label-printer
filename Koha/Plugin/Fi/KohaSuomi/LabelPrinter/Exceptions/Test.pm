package Koha::Plugin::Fi::KohaSuomi::LabelPrinter::Exceptions::Test;

use Modern::Perl;

use Exception::Class (
    'Koha::Plugin::Fi::KohaSuomi::LabelPrinter::Exceptions::Test' => {
        isa => 'Koha::Exceptions::Exception',
        description => 'Something wrong with the database',
    },
);

1;
