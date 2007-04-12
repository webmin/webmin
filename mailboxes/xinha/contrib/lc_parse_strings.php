<?php
die("this script is disabled for security");

/**
  * LC-Parse-Strings-Script
  *
  * This script parses all xinhas source-files and creates base lang-files
  * in the lang-folders (one for base and one every plugin)
  *
  * How To use it: - remove the die() in line 2 (security)
  *                - make sure all lang-folders are writeable for your webserver
  *                - open the contrib/lc_parse_strings.php in your browser
  *                - lang/base.js will be written
  *                - open base.js, translate all strings into your language and save it
  *                  as yourlangauge.js
  *                - send the translated file to the xinha-team
 **/



error_reporting(E_ALL);

$ret = array();
$files = getFiles("../", "js$");
foreach($files as $file)
{
    $fp = fopen($file, "r");
    $data = "";
    while(!feof($fp)) {
        $data .= fread($fp, 1024);
    }

    preg_match_all('#_lc\("([^"]+)"\)|_lc\(\'([^\']+)\'\)#', $data, $m);
    foreach($m[1] as $i) {
        if(trim($i)=="") continue;
        $ret[] = $i;
    }
    foreach($m[2] as $i) {
        if(trim($i)=="") continue;
        $ret[] = $i;
    }

    if(eregi('htmlarea\\.js$', $file)) {
        //toolbar-buttons
        //bold:          [ "Bold"
        preg_match_all('#[a-z]+: *\[ * "([^"]+)"#', $data, $m);
        foreach($m[1] as $i) {
            if(trim($i)=="") continue;
            $ret[] = $i;
        }

        //HTMLArea._lc({key: 'button_bold', string
        preg_match_all('#HTMLArea\\._lc\\({key: \'([^\']*)\'#', $data, $m);
        foreach($m[1] as $i) {
            if(trim($i)=="") continue;
            $ret[] = $i;
        }

        //config.fontname, fontsize and formatblock
        $data = substr($data, strpos($data, "this.fontname = {"), strpos($data, "this.customSelects = {};")-strpos($data, "this.fontname = {"));
        preg_match_all('#"([^"]+)"[ \t]*:[ \t]*["\'][^"\']*["\'],?#', $data, $m);
        foreach($m[1] as $i) {
            if(trim($i)=="") continue;
            $ret[] = $i;
        }
    }
}

$files = getFiles("../popups/", "html$");
foreach($files as $file)
{
    if(preg_match("#custom2.html$#", $file)) continue;
    if(preg_match('#old_#', $file)) continue;
    $ret = array_merge($ret, parseHtmlFile($file));
}
$ret = array_unique($ret);
$langData['HTMLArea'] = $ret;



$plugins = getFiles("../plugins/");
foreach($plugins as $pluginDir)
{
    $plugin = substr($pluginDir, 12);
    if($plugin=="ibrowser") continue;
    $ret = array();

    $files = getFiles("$pluginDir/", "js$");
    $files = array_merge($files, getFiles("$pluginDir/popups/", "html$"));
    $files = array_merge($files, getFiles("$pluginDir/", "php$"));
    foreach($files as $file)
    {
        $fp = fopen($file, "r");
        $data = "";
        if($fp) {
            echo "$file open...<br>";
            while(!feof($fp)) {
              $data .= fread($fp, 1024);
            }
            preg_match_all('#_lc\("([^"]+)"|_lc\(\'([^\']+)\'#', $data, $m);
            foreach($m[1] as $i) {
                if(trim(strip_tags($i))=="") continue;
                $ret[] = $i;
            }
            foreach($m[2] as $i) {
                if(trim(strip_tags($i))=="") continue;
                $ret[] = $i;
            }
        }
    }

    if($plugin=="TableOperations")
    {
        preg_match_all('#options = \\[([^\\]]+)\\];#', $data, $m);
        foreach($m[1] as $i) {
            preg_match_all('#"([^"]+)"#', $i, $m1);
            foreach($m1[1] as $i) {
                $ret[] = $i;
            }
        }
        
        //["cell-delete",        "td", "Delete cell"],
        preg_match_all('#\\["[^"]+",[ \t]*"[^"]+",[ \t]*"([^"]+)"\\]#', $data, $m);
        foreach($m[1] as $i) {
            $ret[] = $i;
        }
    }


    $files = getFiles("$pluginDir/", "html$");
    $files = array_merge($files, getFiles("$pluginDir/", "php$"));
    foreach($files as $file)
    {
        $ret = array_merge($ret, parseHtmlFile($file, $plugin));
    }
    
    $files = getFiles("$pluginDir/popups/", "html$");
    foreach($files as $file)
    {
        $ret = array_merge($ret, parseHtmlFile($file, $plugin));
    }
    $ret = array_unique($ret);

    $langData[$plugin] = $ret;
}

foreach($langData as $plugin=>$strings)
{
    if(sizeof($strings)==0) continue;
    

    $data = "// I18N constants\n";
    $data .= "//\n";
    $data .= "//LANG: \"base\", ENCODING: UTF-8\n";
    $data .= "//Author: Translator-Name, <email@example.com>\n";
    $data .= "// FOR TRANSLATORS:\n";
    $data .= "//\n";
    $data .= "//   1. PLEASE PUT YOUR CONTACT INFO IN THE ABOVE LINE\n";
    $data .= "//      (at least a valid email address)\n";
    $data .= "//\n";
    $data .= "//   2. PLEASE TRY TO USE UTF-8 FOR ENCODING;\n";
    $data .= "//      (if this is not possible, please include a comment\n";
    $data .= "//       that states what encoding is necessary.)\n";
    $data .= "\n";
    $data .= "{\n";
    sort($strings);
    foreach($strings as $string) {
        $string = str_replace(array('\\', '"'), array('\\\\', '\\"'), $string);
        $data .= "  \"".$string."\": \"\",\n";
    }
    $data = substr($data, 0, -2);
    $data .= "\n";
    $data .= "}\n";

    if($plugin=="HTMLArea")
        $file = "../lang/base.js";
    else
        $file = "../plugins/$plugin/lang/base.js";
    
    $fp = fopen($file, "w");
    if(!$fp) continue;
    fwrite($fp, $data);
    fclose($fp);
    echo "$file written...<br>";
}




function parseHtmlFile($file, $plugin="")
{
    $ret = array();
    
    $fp = fopen($file, "r");
    if(!$fp) {
        die("invalid fp");
    }
    $data = "";
    while(!feof($fp)) {
        $data .= fread($fp, 1024);
    }
    
    if($plugin=="FormOperations" || $plugin=="SuperClean" || $plugin=="Linker") {
        //<l10n>-tags for inline-dialog or panel-dialog based dialogs
        $elems = array("l10n");
    } else {
        $elems = array("title", "input", "select", "legend", "span", "option", "td", "button", "div", "label");
    }
    foreach($elems as $elem) {
        preg_match_all("#<{$elem}[^>]*>([^<^\"]+)</$elem>#i", $data, $m);
        foreach($m[1] as $i) {
            if(trim(strip_tags($i))=="") continue;
            if($i=="/") continue;
            if($plugin=="ImageManager" && preg_match('#^--+$#', $i)) continue; //skip those ------
            if($plugin=="CharacterMap" && preg_match('#&[a-z0-9]+;#i', trim($i)) || $i=="@") continue;
            if($plugin=="SpellChecker" && preg_match('#^\'\\.\\$[a-z]+\\.\'$#', $i)) continue;
            $ret[] = trim($i);
        }
    }
    
    if($plugin=="FormOperations" || $plugin=="SuperClean" || $plugin=="Linker")
    {
        //_( for inline-dialog or panel-dialog based dialogs
        preg_match_all('#"_\(([^"]+)\)"#i', $data, $m);
        foreach($m[1] as $i) {
            if(trim($i)=="") continue;
            $ret[] = $i;
        }
    }
    else
    {
        preg_match_all('#title="([^"]+)"#i', $data, $m);
        foreach($m[1] as $i) {
            if(trim(strip_tags($i))=="") continue;
            if(strip_tags($i)==" - ") continue; //skip those - (ImageManager)
            $ret[] = $i;
        }
    }
    return($ret);
}


function getFiles($rootdirpath, $eregi_match='') {
 $array = array();
 if ($dir = @opendir($rootdirpath)) {
   $array = array();
   while (($file = readdir($dir)) !== false) {
     if($file=="." || $file==".." || $file==".svn") continue;
      if($eregi_match=="")
        $array[] = $rootdirpath."/".$file;
      else if(eregi($eregi_match,$file))
        $array[] = $rootdirpath."/".$file;
      
   }
   closedir($dir);
 }
 return $array;
}





?>
