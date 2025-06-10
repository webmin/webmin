#!/usr/local/bin/perl
# Show a form for selecting the source for a map

require './postfix-lib.pl';
&ReadParse();
&error_setup($text{'chooser_err'});
@oldmaps = &get_maps_types_files($in{'map'});

# Build a list of maps from inputs
for($i=0; defined($t = $in{"type_".$i}); $i++) {
	next if (!$t);

	if ($t eq "hash") {
		# Simple file
		$in{"hash_$i"} =~ /^[\/\.]\S+$/ ||
			&error(&text('chooser_ehash', $i+1));
		push(@maps, "hash:".$in{"hash_$i"});
		}
	elsif ($t eq "regexp") {
		# Regular expressions file
		$in{"regexp_$i"} =~ /^[\/\.]\S+$/ ||
			&error(&text('chooser_eregexp', $i+1));
		push(@maps, "regexp:".$in{"regexp_$i"});
		}
	elsif ($t eq "pcre") {
		# Perl-style regular expressions file
		$in{"pcre_$i"} =~ /^[\/\.]\S+$/ ||
			&error(&text('chooser_epcre', $i+1));
		push(@maps, "pcre:".$in{"pcre_$i"});
		}
	elsif ($t eq "mysqlsrc") {
		# Common MySQL source
		push(@maps, "mysql:".$in{"mysqlsrc_$i"});
		}
	elsif ($t eq "mysql") {
		# MySQL database
		if ($oldmaps[$i]->[0] eq "mysql" &&
		    $oldmaps[$i]->[1] =~ /^[\/\.]/) {
			# Same file as before
			$file = $oldmaps[$i]->[1];
			}
		else {
			# Pick a filename based on the field
			$file = &guess_config_dir()."/".$in{'mapname'}.
				($i ? ".$i" : "").".mysql.conf";
			}
		# Validate and save MySQL settings, starting with host
		if ($in{"mhosts_${i}_def"}) {
			&save_backend_config($file, "hosts", undef);
			}
		else {
			$in{"mhosts_$i"} =~ /\S/ ||
				&error(&text('chooser_emhosts', $i+1));
			&save_backend_config($file, "hosts", $in{"mhosts_$i"});
			}

		# Username
		$in{"muser_$i"} =~ /^\S+$/ ||
			&error(&text('chooser_emuser', $i+1));
		&save_backend_config($file, "user", $in{"muser_$i"});

		# Password
		$in{"mpassword_$i"} =~ /^\S+$/ ||
			&error(&text('chooser_empassword', $i+1));
		&save_backend_config($file, "password", $in{"mpassword_$i"});

		# Custom query
		if (&compare_version_numbers($postfix_version, 2.2) >= 0) {
			if ($in{"mquery_${i}_def"}) {
				&save_backend_config($file, "query", undef);
				}
			else {
				$in{"mdbname_$i"} =~ /\S/ ||
					&error(&text('chooser_emquery', $i+1));
				&save_backend_config($file, "query",
						     $in{"mquery_$i"});
				}
			}

		# Database name 
		$in{"mdbname_$i"} =~ /^\S+$/ ||
			&error(&text('chooser_emdbname', $i+1));
		&save_backend_config($file, "dbname", $in{"mdbname_$i"});

		# Table name
		$in{"mtable_$i"} =~ /^\S+$/ ||
			&error(&text('chooser_emtable', $i+1));
		&save_backend_config($file, "table", $in{"mtable_$i"});

		# Value field
		$in{"mselect_field_$i"} =~ /^[a-z0-9\_]+$/i ||
			&error(&text('chooser_emselect_field', $i+1));
		&save_backend_config($file, "select_field",
				     $in{"mselect_field_$i"});

		# Key field
		$in{"mwhere_field_$i"} =~ /^[a-z0-9\_]+$/i ||
			&error(&text('chooser_emwhere_field', $i+1));
		&save_backend_config($file, "where_field",
				     $in{"mwhere_field_$i"});

		# Additional select conditions
		if ($in{"madditional_conditions_${i}_def"}) {
			&save_backend_config($file, "additional_conditions");
			}
		else {
			$in{"madditional_conditions_$i"} =~ /\S/ ||
				&error(&text('chooser_emadditional', $i+1));
			&save_backend_config($file, "additional_conditions",
					     $in{"madditional_conditions_$i"});
			}

		push(@maps, "mysql:$file");
		push(@files, $file);
		}
	elsif ($t eq "ldap") {
		# LDAP database
		if ($oldmaps[$i]->[0] eq "ldap" &&
		    $oldmaps[$i]->[1] =~ /^[\/\.]/) {
			# Same file as before
			$file = $oldmaps[$i]->[1];
			}
		else {
			# Pick a filename based on the field
			$file = &guess_config_dir()."/".$in{'mapname'}.
				($i ? ".$i" : "").".ldap.conf";
			}

		# Save LDAP server hostname
		if ($in{"lserver_host_${i}_def"}) {
			&save_backend_config($file, "server_host", undef);
			}
		else {
			$in{"lserver_host_$i"} =~ /\S/ ||
				&error(&text('chooser_elserver_host', $i+1));
			&save_backend_config($file, "server_host",
					     $in{"lserver_host_$i"});
			}

		# LDAP port number
		if ($in{"lserver_port_${i}_def"}) {
			&save_backend_config($file, "server_port", undef);
			}
		else {
			$in{"lserver_port_$i"} =~ /^\d+$/ ||
				&error(&text('chooser_elserver_port', $i+1));
			&save_backend_config($file, "server_port",
					     $in{"lserver_port_$i"});
			}

		# Start TLS?
		&save_backend_config($file, "start_tls", $in{"lstart_tls_$i"});

		# Search base
		$in{"lsearch_base_$i"} =~ /\S/ ||
			&error(&text('chooser_elsearch_base', $i+1));
		&save_backend_config($file, "search_base",
				     $in{"lsearch_base_$i"});

		# Query filter
		if ($in{"lquery_filter_${i}_def"}) {
			&save_backend_config($file, "query_filter", undef);
			}
		else {
			$in{"lquery_filter_$i"} =~ /^\S+$/ ||
				&error(&text('chooser_elquery_filter', $i+1));
			&save_backend_config($file, "query_filter",
					     $in{"lquery_filter_$i"});
			}

		# Resulting attribute
		if ($in{"lresult_attribute_${i}_def"}) {
			&save_backend_config($file, "result_attribute", undef);
			}
		else {
			$in{"lresult_attribute_$i"} =~ /^\S+$/ ||
			    &error(&text('chooser_elresult_attribute', $i+1));
			&save_backend_config($file, "result_attribute",
					     $in{"lresult_attribute_$i"});
			}

		# Search scope
		&save_backend_config($file, "scope", $in{"lscope_$i"} || undef);

		# Login to server?
		&save_backend_config($file, "bind", $in{"lbind_$i"});

		# Username
		if ($in{"lbind_dn_${i}_def"}) {
			&save_backend_config($file, "bind_dn", undef);
			}
		else {
			$in{"lbind_dn_$i"} =~ /\S/ ||
				&error(&text('chooser_elbind_dn', $i+1));
			&save_backend_config($file, "bind_dn",
					     $in{"lbind_dn_$i"});
			}

		# Password
		if ($in{"lbind_pw_${i}_def"}) {
			&save_backend_config($file, "bind_pw", undef);
			}
		else {
			$in{"lbind_pw_$i"} =~ /\S/ ||
				&error(&text('chooser_elbind_pw', $i+1));
			&save_backend_config($file, "bind_pw",
					     $in{"lbind_pw_$i"});
			}

		push(@maps, "ldap:$file");
		push(@files, $file);
		}
	elsif ($t eq "other") {
		# Some other map
		$in{"other_$i"} =~ /^[a-z0-9]+:[^, ]+$/i ||
			&error(&text('chooser_eother', $i+1));
		push(@maps, $in{"other_$i"});
		}
	else {
		&error("Unknown type $t");
		}
	}
@maps || &error($text{'chooser_enone'});

# Write out mysql and LDAP files
@files = &unique(@files);
@newfiles = map { !-r $_ } @files;
foreach $f (@files) {
	&lock_file($f);
	}
&flush_file_lines(@files);
foreach $f (@newfiles) {
	&set_ownership_permissions(undef, undef, 0700, $f);
	}
foreach $f (@files) {
	&unlock_file($f);
	}

# Create final string for map
$str = join(",", @maps);
&popup_header($text{'chooser_title'});

print <<EOF;
<script>
top.opener.ifield.value = "$str";
window.close();
</script>
EOF

if (@files) {
	&webmin_log("backend", undef, $in{'map_name'});
	}
&popup_footer();

