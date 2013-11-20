# tunnel-lib.pl
# Common functions for the HTTP-tunnel module

BEGIN { push(@INC, ".."); };
use WebminCore;
&init_config();

sub get_path {
    my ($file) = @_;
    $file =~ s!/?[^/]*/*$!!;
    return $file;
}

sub pop_path {
    my ($dir, $stack) = @_;
    return get_path($dir) if ( $stack eq 0 );
    $ret = $dir;
    for($x=0; $x <= $stack; $x++) {
        $ret = get_path($ret);
    }
    return $ret;
}

# $ENV{'PATH_INFO'}: /http:/rutweb.com/wp-content/themes/olympus/style.css
# content: url(css/bootstrap.css)
# path: css/bootstrap.css
# translate to: http://rutweb.com/wp-content/themes/olympus/css/bootstrap.css
# content: url(../css/bootstrap.css)
# path: ../css/bootstrap.css
# translate to: http://rutweb.com/wp-content/themes/css/bootstrap.css

# base on simplify_path
sub resolv_path {
    my ($pathinfo, $path) = @_;

    # fix schema
    $pathinfo =~ s/^\///g;
    $pathinfo =~ s/^(http:\/|https:\/)(?!\/.*)/$1\/$2/gi;

    $path =~ s/^\/+//g;
    $path =~ s/\/+$//g;
    my @bits = split(/\/+/, $path);
    my @fixedbits = ();
    my $cnt = 0;
    foreach my $b (@bits) {
        if ($b eq ".") {
            # do nothing
        } elsif ($b eq "..") {
            $cnt++;
            pop(@fixedbits);
        } else {
            # Add dir to list
            push(@fixedbits, $b);
        }
    }
    $fpath = pop_path($pathinfo, $cnt);
    return "$fpath/".join('/', @fixedbits);
}

1;

