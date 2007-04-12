#!/usr/local/bin/perl
# list_exports.cgi
# Output info about NFS exports

require './file-lib.pl';
print "Content-type: text/plain\n\n";
if ($access{'uid'}) {
	# User has no access to NFS
	print "0\n";
	exit;
	}

&read_acl(\%acl, undef);
%einfo = &get_module_info("exports");
%dinfo = &get_module_info("dfsadmin");
#%binfo = &get_module_info("bsdexports");	# too hard

if (%einfo && &check_os_support(\%einfo)) {
	# Linux NFS exports
	&module_check("exports");
	if (!&has_command("rpc.nfsd") && !&has_command("nfsd")) {
		print "0\n";
		exit;
		}
	print "1\n";
	&foreign_require("exports", "exports-lib.pl");
	foreach $e (&foreign_call("exports", "list_exports")) {
		push(@{$exp{$e->{'dir'}}}, $e)
			if ($e->{'dir'} !~ /:/ && $e->{'host'} !~ /:/);
		}
	foreach $d (keys %exp) {
		local $host;
		foreach $e (@{$exp{$d}}) {
			local $o = $e->{'options'};
			$host .= sprintf ":%s:%d:%d",
				$e->{'host'} ? $e->{'host'} : '*',
				defined($o->{'ro'}),
				defined($o->{'all_squash'}) ? 0 :
				defined($o->{'no_root_squash'}) ? 2 : 1;
			}
		print &make_chroot($d),$host,"\n";
		}
	}
elsif (%dinfo && &check_os_support(\%dinfo)) {
	# Solaris NFS shares
	&module_check("dfsadmin");
	print "2\n";
	&foreign_require("dfsadmin", "dfs-lib.pl");
	foreach $s (&foreign_call("dfsadmin", "list_shares")) {
		$opts = &foreign_call("dfsadmin", "parse_options",$s->{'opts'});
		$opts->{'ro'} = '-' if (!defined($opts->{'ro'}));
		$opts->{'ro'} =~ s/:/ /g;
		$opts->{'rw'} = '-' if (!defined($opts->{'rw'}));
		$opts->{'rw'} =~ s/:/ /g;
		$opts->{'root'} = '-' if (!defined($opts->{'root'}));
		$opts->{'root'} =~ s/:/ /g;
		printf "%s:%s:%s:%s:%s\n",
			&make_chroot($s->{'dir'}), $opts->{'ro'}, $opts->{'rw'},
			$opts->{'root'}, $s->{'desc'};
		}
	}
elsif (%binfo && &check_os_support(\%binfo)) {
	# BSD NFS exports
	&module_check("bsdexports");
	print "3\n";
	&foreign_require("bsdexports", "bsdexports-lib.pl");
	foreach $e (&foreign_call("bsdexports", "list_exports")) {
		foreach $d (@{$e->{'dirs'}}) {
			printf "%s:%s", $d, $e->{'ro'} ? 1 : 0;
			if ($e->{'network'}) {
				printf ":%s/%s\n",
					$e->{'network'}, $e->{'mask'};
				}
			else {
				foreach $h (@{$e->{'hosts'}}) {
					print ":$h";
					}
				print "\n";
				}
			}
		}
	}
else {
	# No NFS modules installed or supported
	print "0\n";
	}

sub module_check
{
if (!$acl{$base_remote_user,$_[0]}) {
	print "0\n";
	exit;
	}
}

