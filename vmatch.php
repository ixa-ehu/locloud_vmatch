<?php

sleep(1);
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
else if(!empty($_POST['record'])){
  $log_mode = "POST";
  $log_parameters = "record: " . $_POST['record'];
  if(!empty($_POST['lang'])){
    $lang = $_POST['lang'];
    $log_parameters .= "  // lang: " . $lang;
  }
  else{
    $lang = $default_lang;
  }
  
  $text = record_to_text($_POST['record']);
  match($text, $dictionary, $lang);
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

  # $text = "dc:subject@@@testua@@@dc:title@@@testua@@@"

  $new_text = stripslashes($text);

  $do_match_result = shell_exec("echo \"$new_text\" | perl ./do_match.pl $dictionary $lang");

  # do_match_result = field@@@number@@@match_text_itzultzen_duena@@@@field@@@number@@@match_text_itzultzen_duena@@@@
  # eta match_text_itzultzen_duena: matchURI_1@@dict_1:::matchURI_2@@dict_2::: ... matchURI_N@@dict_N:::

  $new_data = array();
  $resources = array();

  $fnmatches = explode('@@@@', $do_match_result);
  array_pop($fnmatches); //there is nothing after the last "@@@@"
  foreach ($fnmatches as &$fnmatch) {
      list($field, $field_n, $match_text_result) = explode("@@@", $fnmatch);
      foreach (match_field($match_text_result, $field, $field_n) as $resource) {
          array_push($resources, $resource);
      }
  }
  $new_data['Resources'] = $resources;
  deliver_response(200,"Success",$new_data);
}

function match_field($result_match, $field, $field_n) {

  if($result_match != ""){

    $matches = explode(":::", $result_match);

    $concepts = array();
    array_pop($matches); //there is nothing after the last ":::"
    foreach ($matches as &$uris) {
      // uri@@dict   example: http://ait113/tematres/mon_type/?tema=4911@@Monument Type Thesaurus
      list($uri, $dict) = explode("@@", $uris);
      $concept = array(
          'field' => $field,
          'field_n' => $field_n,
          'URI' => $uri,
          'vocab' => $dict
      );
      array_push($concepts, $concept);
    }
  }
  return $concepts;
}


function record_to_text($record){
# record = [{"field" : "dc:title","text":"Major Oak" },{"field":"dc:subject","text":"painting"},{"field":"dc:subject","text":"writing"}]'

  $text = "";
  $json = json_decode($record);

  foreach($json as $fields){
    $text = $text . $fields->field . "@@@" . $fields->text . "@@@";
  }

  return $text; # $text = "dc:title@@@Major Oak@@@dc:subject@@@painting@@@dc:subject@@@writing@@@"
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