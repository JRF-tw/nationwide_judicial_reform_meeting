var num = 0;
$('a[href$="delete"]').each(function(){
  if (num < 20){
  console.log($(this).attr('href'));
  window.open($(this).attr('href'), '_blank');
  num += 1;
  }
});

javascript:$('input.btn.btn-danger').click();