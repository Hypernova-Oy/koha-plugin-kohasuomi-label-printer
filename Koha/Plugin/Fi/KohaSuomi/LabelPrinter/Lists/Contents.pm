package Koha::Plugin::Fi::KohaSuomi::LabelPrinter::Lists::Contents;

use Modern::Perl;
use Try::Tiny;
use Scalar::Util qw(blessed);

use Mojo::Base 'Mojolicious::Controller';

use Koha::Virtualshelves;

sub add {
    my $c = shift->openapi->valid_input or return;

    try {
        my $body = $c->req->json;
        my $user = $c->stash('koha.user');
        if ($body->{listname} eq 'labels printing') {
            my $shelf = Koha::Virtualshelves->find( { owner => $user->borrowernumber, shelfname => $body->{listname} } );
            if (!$shelf) {
                $shelf = eval { Koha::Virtualshelf->new( {
                    shelfname => 'labels printing',
                    category => 1,
                    owner => $user->borrowernumber,
                    sortfield => undef,
                    allow_add => 0,
                    allow_delete_own => 1,
                    allow_delete_other => 0,
                    } )->store; };
            }
            my $content = Koha::Virtualshelfcontent->new(
                {
                    shelfnumber => $shelf->shelfnumber,
                    biblionumber => $body->{biblionumber},
                    borrowernumber => $body->{borrowernumber},
                    flags => $body->{itemnumber},
                }
            )->store;
            return $c->render(status => 200, openapi => $content);
        } else {
            return $c->render( status => 400, openapi => {});
        }
    } catch {
        $c->unhandled_exception($_);
    };
}
sub delete {
    my $c = shift->openapi->valid_input or return;

    my $body = $c->req->json;
    my $shelf = Koha::Virtualshelves->find({owner => $body->{borrowernumber}, shelfname => $body->{listname}});
    my $content = $shelf->get_contents;
    unless ($content) {
        return $c->render( status  => 404,
                           openapi => { error => "Notice not found" } );
    }

    my $res = $content->delete;

    if ($res eq '1') {
        return $c->render( status => 200, openapi => {});
    } elsif ($res eq '-1') {
        return $c->render( status => 404, openapi => {});
    } else {
        return $c->render( status => 400, openapi => {});
    }
}

1;
