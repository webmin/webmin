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
		if ($postfix_version >= 2.2) {
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
		# XXX
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
&flush_file_lines(&unique(@files));

# Create final string for map
$str = join(",", @maps);
&popup_header($text{'chooser_title'});

print <<EOF;
<script>
top.opener.ifield.value = "$str";
window.close();
</script>
EOF

&popup_footer();

