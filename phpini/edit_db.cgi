#!/usr/local/bin/perl
# Show options related to MySQL and other database connections

require './phpini-lib.pl';
&ReadParse();
&can_php_config($in{'file'}) || &error($text{'list_ecannot'});
$conf = &get_config($in{'file'});

&ui_print_header("<tt>".&html_escape($in{'file'})."</tt>",
		 $text{'db_title'}, "");

print &ui_form_start("save_db.cgi", "post");
print &ui_hidden("file", $in{'file'}),"\n";

# First section is for MySQL options
print &ui_table_start($text{'db_header1'}, "width=100%", 2);

# Allow persistent MySQL connections
print &ui_table_row(&opt_help($text{'db_persist'}, 'mysql.allow_persistent'),
	    &onoff_radio("mysql.allow_persistent"));

# Max persistent connections
$mp = &find_value("mysql.max_persistent", $conf);
print &ui_table_row(&opt_help($text{'db_maxpersist'}, 'mysql.max_persistent'),
	    &ui_opt_textbox("mysql.max_persistent", $mp <= 0 ? undef : $mp,
			    5, $text{'db_unlimited'}));

# Max total connections
$mp = &find_value("mysql.max_links", $conf);
print &ui_table_row(&opt_help($text{'db_maxlinks'}, 'mysql.max_links'),
	    &ui_opt_textbox("mysql.max_links", $mp <= 0 ? undef : $mp,
			    5, $text{'db_unlimited'}));

# Connection timeout
$ct = &find_value("mysql.connect_timeout", $conf);
print &ui_table_row(&opt_help($text{'db_timeout'}, 'mysql.connect_timeout'),
	    &ui_opt_textbox("mysql.connect_timeout", $ct <= 0 ? undef : $ct,
			    5,$text{'default'})." ".$text{'db_s'});

# Default host
print &ui_table_row(&opt_help($text{'db_host'}, 'mysql.default_host'),
	    &ui_opt_textbox("mysql.default_host",
			    &find_value("mysql.default_host", $conf),
			    30, "<tt>localhost</tt>"));

# Default port
print &ui_table_row(&opt_help($text{'db_port'}, 'mysql.default_port'),
	    &ui_opt_textbox("mysql.default_port",
			    &find_value("mysql.default_port", $conf),
			    5, "<tt>3306</tt>"));

print &ui_table_end();


# Second section is for PostgreSQL options
print &ui_table_start($text{'db_header2'}, "width=100%", 2);

# Allow persistent PostgreSQL connections
print &ui_table_row(&opt_help($text{'db_persist'}, 'pgsql.allow_persistent'),
	    &onoff_radio("pgsql.allow_persistent"));

# Re-open persistent PostgreSQL connections
print &ui_table_row(&opt_help($text{'db_reset'}, 'pgsql.auto_reset_persistent'),
	    &onoff_radio("pgsql.auto_reset_persistent"));

# Max persistent connections
$mp = &find_value("pgsql.max_persistent", $conf);
print &ui_table_row(&opt_help($text{'db_maxpersist'}, 'pgsql.max_persistent'),
	    &ui_opt_textbox("pgsql.max_persistent", $mp <= 0 ? undef : $mp,
			    5, $text{'db_unlimited'}));

# Max total connections
$mp = &find_value("pgsql.max_links", $conf);
print &ui_table_row(&opt_help($text{'db_maxlinks'}, 'pgsql.max_links'),
	    &ui_opt_textbox("pgsql.max_links", $mp <= 0 ? undef : $mp,
			    5, $text{'db_unlimited'}));

print &ui_table_end();

print &ui_form_end([ [ "save", $text{'save'} ] ]);

&ui_print_footer("list_ini.cgi?file=".&urlize($in{'file'}),
		 $text{'list_return'});
