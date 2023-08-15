#!/usr/local/bin/perl
# Fix the Webmin repository URL and key

require './webmin-lib.pl';
&ReadParse();
my $devkey = "$module_root_directory/developers-key.asc";

if (-r $webmin_yum_repo_file) {
	# Fix up YUM repo
	&lock_file($webmin_yum_repo_file);
	my $lref = &read_file_lines($webmin_yum_repo_file);
	foreach my $l (@$lref) {
		if ($l =~ /^\s*baseurl\s*=\s*(\S+)/) {
			$l = "baseurl=".$webmin_yum_repo_url;
			}
		elsif ($l =~ /^\s*mirrorlist\s*=\s*(\S+)/) {
			$l = "mirrorlist=".$webmin_yum_repo_mirrorlist;
			}
		elsif ($l =~ /^\s*gpgkey\s*=\s*file:\/\/(\S+)/) {
			&copy_source_dest($devkey, $webmin_yum_repo_key)
				if (!-r $webmin_yum_repo_key);
			$l = "gpgkey=file://".$webmin_yum_repo_key;
			}
		}
	&flush_file_lines($webmin_yum_repo_file);
	&unlock_file($webmin_yum_repo_file);
	&system_logged("rpm --import $webmin_yum_repo_key >/dev/null 2>&1");
	}

my $ffixed = 0;
foreach my $repo ($webmin_apt_repo_file, $global_apt_repo_file) {
	# Fix APT repo
	next if (!-r $repo);
	&lock_file($repo);
	my $lref = &read_file_lines($repo);
	my $fixed = 0;
	my $lreffix = sub {
		my ($l) = @_;
		if ($ffixed) {
			return "";
			}
		else {
			return $l;
			}
	};
	foreach my $l (@$lref) {
		if ($l =~ /^\s*deb\s+.*?((http|https):\/\/download.webmin.com\/download\/repository)\s+sarge\s+contrib/) {
			$l = &$lreffix("deb [signed-by=$webmin_apt_repo_key] $webmin_apt_repo_url stable contrib");
			$fixed++;
			}
		}
	&flush_file_lines($repo);
	&unlock_file($repo);
	if ($fixed) {
		$ffixed++;
		}
	}
if ($ffixed) {
	# Put the new key into place
	&system_logged("gpg --import $devkey >/dev/null 2>&1");
	my ($asckey, $err);
	my $ex = &execute_command("gpg --dearmor", $devkey, \$asckey, \$err);
	&error(&html_escape($err)) if ($ex);
	&lock_file($webmin_apt_repo_key);
	&write_file_contents($webmin_apt_repo_key, $asckey);
	&unlock_file($webmin_apt_repo_key);
	}

&webmin_log("fixrepo");
&redirect(get_referer_relative());
