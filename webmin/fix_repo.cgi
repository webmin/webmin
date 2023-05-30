#!/usr/local/bin/perl
# Fix the Webmin repository URL and key

require './webmin-lib.pl';
&ReadParse();

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
			&copy_source_dest(
			    "$module_root_directory/developers-key.asc",
			    $webmin_yum_repo_key)
				if (!-r $webmin_yum_repo_key);
			$l = "gpgkey=file://".$webmin_yum_repo_key;
			}
		}
	&flush_file_lines($webmin_yum_repo_file);
	&unlock_file($webmin_yum_repo_file);
	&system_logged("rpm --import $webmin_yum_repo_key >/dev/null 2>&1 </dev/null");
	}

&webmin_log("fixrepo");
&redirect(get_referer_relative());
