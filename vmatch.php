<?php

$log_date = date("Y-m-d H:i:s");

$dictionary = "dict.txt";
$default_lang = "en";

if(!empty($_GET['text'])){
  $log_mode = "GET";
  $log_parameters = "text: " . $_GET['text'];
  if(!empty($_GET['lang'])){
    $lang = $_GET['lang'];
    $log_parameters .= "  // lang: " . $lang;
  }
  else{
    $lang = $default_lang;
  }

  match($_GET['text'], $dictionary, $lang);

}
else if(!empty($_POST['text'])){
  $log_mode = "POST";
  $log_parameters = "text: " . $_POST['text'];
  if(!empty($_POST['lang'])){
    $lang = $_POST['lang'];
    $log_parameters .= "  // lang: " . $lang;
  }
  else{
    $lang = $default_lang;
  }

  match($_POST['text'], $dictionary, $lang);

}
else{
  deliver_response(400,"Invalid Request: missing 'text' parameter",NULL);
  $log_parameters = "missing 'text' parameter";
}


# log
if (!empty($_SERVER['HTTP_CLIENT_IP'])) {
    $ip = $_SERVER['HTTP_CLIENT_IP'];
} elseif (!empty($_SERVER['HTTP_X_FORWARDED_FOR'])) {
    $ip = $_SERVER['HTTP_X_FORWARDED_FOR'];
} else {
    $ip = $_SERVER['REMOTE_ADDR'];
}

$logString = "[" . $log_date . "] - " . $ip . " - " . $log_mode . " - Parameter(s): " . $log_parameters . "\n";
$logFile = "/home/lcuser/logs/vmatch_access.log";
$fh = fopen($logFile, 'a') or die ('Cannot open file');
fwrite($fh, $logString);
fclose($fh);





function match($text,$dictionary,$lang){

  $new_text = stripslashes($text);

  $result_match = shell_exec("perl ./do_match.pl $dictionary $lang \"$new_text\"");
# restult_match = matchURI_1@@dict_1:::matchURI_2@@dict_2::: ... matchURI_N@@dict_N

  $new_data = array();

  if($result_match != ""){

    $matches = explode(":::", $result_match);

    $concepts = array();
    array_pop($matches); //there is nothing after the last ":::"
    foreach ($matches as &$uris) {
      // uri@@dict   example: http://ait113/tematres/mon_type/?tema=4911@@Monument Type Thesaurus
      list($uri, $dict) = explode("@@", $uris);
      $concept = array(
		       'URI' => $uri,
		       'vocab' => $dict
		       );
      array_push($concepts, $concept);
    }


    $new_data['Resources'] = $concepts;
  }
  deliver_response(200,"Success",$new_data);

}



function deliver_response($status,$status_message,$data){

  header("HTTP/1.1 $status status_message");
  header('Content-Type: application/json; charset=utf-8');

  $response['Status'] = $status;
  $response['Status_message'] = $status_message;
  $response['data'] = $data;

  $json_response = json_encode($response);
  echo $json_response;


}


?>