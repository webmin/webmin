
do 'bind8-lib.pl';

sub list_system_info
{
my ($data, $in) = @_;
my @rv;
if (&foreign_available($module_name) && $access{'defaults'}) {
	# Show DNSSEC client config errors
	my $err = &check_dnssec_client();
	if ($err) {
		push(@rv, { 'type' => 'warning',
			    'level' => 'warn',
			    'warning' => $err });
		}
	}
if (&foreign_available($module_name) && !$access{'noconfig'}) {
	# Show DNSSEC expired domains
	my @exps = &list_dnssec_expired_domains();
	if (@exps) {
		my @doms = map { $_->{'name'}." (".&make_date($_->{'expiry'}, 1).")" } @exps;
		my $msg = &text('index_eexpired', join(", ", @doms))."<p>\n";
		my $job = &get_dnssec_cron_job();
		if (!$job) {
			$msg .= &text('index_eexpired_conf',
				      &ui_link("/$module_name/conf_dnssec.cgi",
					       $text{'dnssec_title'}));
			}
		else {
			$msg .= &text('index_eexpired_mod',
				      &ui_link("/$module_name/",
					       $text{'index_title'}));
			}
		push(@rv, { 'type' => 'warning',
			    'level' => 'danger',
			    'warning' => $msg });
		}
	}
return @rv;
}
