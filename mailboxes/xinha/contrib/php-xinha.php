<?php
  /** Write the appropriate xinha_config directives to pass data to a PHP (Plugin) backend file.
   *
   *  ImageManager Example:
   *  The following would be placed in step 3 of your configuration (see the NewbieGuide 
   *  (http://xinha.python-hosting.com/wiki/NewbieGuide)
   *
   * <script language="javascript">
   *  with (xinha_config.ImageManager)
   *  { 
   *    <?php 
   *      xinha_pass_to_php_backend
   *      (       
   *        array
   *        (
   *         'images_dir' => '/home/your/directory',
   *         'images_url' => '/directory'
   *        )
   *      )
   *    ?>
   *  }
   *  </script>
   * 
   */
      
  function xinha_pass_to_php_backend($Data, $KeyLocation = 'Xinha:BackendKey')
  {
   
    $bk = array();
    $bk['data']       = serialize($Data);
    
    @session_start();
    if(!isset($_SESSION[$KeyLocation]))
    {
      $_SESSION[$KeyLocation] = uniqid('Key_');
    }
    
    $bk['session_name'] = session_name();      
    $bk['key_location'] = $KeyLocation;      
    $bk['hash']         = 
      function_exists('sha1') ? 
        sha1($_SESSION[$KeyLocation] . $bk['data']) 
      : md5($_SESSION[$KeyLocation] . $bk['data']);
      
      
    // The data will be passed via a postback to the 
    // backend, we want to make sure these are going to come
    // out from the PHP as an array like $bk above, so 
    // we need to adjust the keys.
    $backend_data = array();
    foreach($bk as $k => $v)
    {
      $backend_data["backend_data[$k]"] = $v; 
    }
    
    // The session_start() above may have been after data was sent, so cookies
    // wouldn't have worked.
    $backend_data[session_name()] = session_id();
    
    echo 'backend_data = ' . xinha_to_js($backend_data) . "; \n";
    
  }  
   
  /** Convert PHP data structure to Javascript */
  
  function xinha_to_js($var, $tabs = 0)
  {
    if(is_numeric($var))
    {
      return $var;
    }
  
    if(is_string($var))
    {
      return "'" . xinha_js_encode($var) . "'";
    }
  
    if(is_array($var))
    {
      $useObject = false;
      foreach(array_keys($var) as $k) {
          if(!is_numeric($k)) $useObject = true;
      }
      $js = array();
      foreach($var as $k => $v)
      {
        $i = "";
        if($useObject) {
          if(preg_match('#^[a-zA-Z]+[a-zA-Z0-9]*$#', $k)) {
            $i .= "$k: ";
          } else {
            $i .= "'$k': ";
          }
        }
        $i .= xinha_to_js($v, $tabs + 1);
        $js[] = $i;
      }
      if($useObject) {
          $ret = "{\n" . xinha_tabify(implode(",\n", $js), $tabs) . "\n}";
      } else {
          $ret = "[\n" . xinha_tabify(implode(",\n", $js), $tabs) . "\n]";
      }
      return $ret;
    }
  
    return 'null';
  }
    
  /** Like htmlspecialchars() except for javascript strings. */
  
  function xinha_js_encode($string)
  {
    static $strings = "\\,\",',%,&,<,>,{,},@,\n,\r";
  
    if(!is_array($strings))
    {
      $tr = array();
      foreach(explode(',', $strings) as $chr)
      {
        $tr[$chr] = sprintf('\x%02X', ord($chr));
      }
      $strings = $tr;
    }
  
    return strtr($string, $strings);
  }
        
   
  /** Used by plugins to get the config passed via 
  *   xinha_pass_to_backend()
  *  returns either the structure given, or NULL
  *  if none was passed or a security error was encountered.
  */
  
  function xinha_read_passed_data()
  {
   if(isset($_REQUEST['backend_data']) && is_array($_REQUEST['backend_data']))
   {
     $bk = $_REQUEST['backend_data'];
     session_name($bk['session_name']);
     @session_start();
     if(!isset($_SESSION[$bk['key_location']])) return NULL;
     
     if($bk['hash']         === 
        function_exists('sha1') ? 
          sha1($_SESSION[$bk['key_location']] . $bk['data']) 
        : md5($_SESSION[$bk['key_location']] . $bk['data']))
     {
       return unserialize(ini_get('magic_quotes_gpc') ? stripslashes($bk['data']) : $bk['data']);
     }
   }
   
   return NULL;
  }
   
  /** Used by plugins to get a query string that can be sent to the backend 
  * (or another part of the backend) to send the same data.
  */
  
  function xinha_passed_data_querystring()
  {
   $qs = array();
   if(isset($_REQUEST['backend_data']) && is_array($_REQUEST['backend_data']))
   {
     foreach($_REQUEST['backend_data'] as $k => $v)
     {
       $v =  ini_get('magic_quotes_gpc') ? stripslashes($v) : $v;
       $qs[] = "backend_data[" . rawurlencode($k) . "]=" . rawurlencode($v);
     }       
   }
   
   $qs[] = session_name() . '=' . session_id();
   return implode('&', $qs);
  }
   
    
  /** Just space-tab indent some text */
  function xinha_tabify($text, $tabs)
  {
    if($text)
    {
      return str_repeat("  ", $tabs) . preg_replace('/\n(.)/', "\n" . str_repeat("  ", $tabs) . "\$1", $text);
    }
  }       

  /** Return upload_max_filesize value from php.ini in kilobytes (function adapted from php.net)**/
  function upload_max_filesize_kb() 
  {
    $val = ini_get('upload_max_filesize');
    $val = trim($val);
    $last = strtolower($val{strlen($val)-1});
    switch($last) 
    {
      // The 'G' modifier is available since PHP 5.1.0
      case 'g':
        $val *= 1024;
      case 'm':
        $val *= 1024;
   }
   return $val;
}
?>