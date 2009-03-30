=head1 foobar-lib.pl

Functions for the Foobar Web Server. This is an example Webmin module for a
simple fictional webserver.

=cut

use WebminCore;
init_config();

=head2 list_foobar_websites()

Returns a list of all websites served by the Foobar webserver, as hash
references with C<domain> and C<directory> keys.

=cut
sub list_foobar_websites
{
my @rv;
my $lnum = 0;
open(CONF, $config{'foobar_conf'});
while(<CONF>) {
	s/\r|\n//g;
	s/#.*$//;
	my ($dom, $dir) = split(/\s+/, $_);
	if ($dom && $dir) {
		push(@rv, { 'domain' => $dom,
			    'directory' => $dir,
			    'line' => $lnum });
		}
	$lnum++;
	}
close(CONF);
return @rv;
}

1;

