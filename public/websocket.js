window.onload = function(){
    (function(){
      var show = function(text){
        return toastr.info(text,
        {
          newestOnTop: false,
          progressBar: true,
          positionClass: 'toast-bottom-left',
          showDuration: 300,
          hideDuration: 1000,
          timeOut: 500,
          extendedTimeOut: 10000,
          showEasing: "swing",
          hideEasing: "linear",
          showMethod: "fadeIn",
          hideMethod: "fadeOut"
        });
      };

      var ws       = new WebSocket('ws://' + window.location.host + "/statuses");
      ws.onopen    = function()  { show('websocket opened'); };
      ws.onclose   = function()  { show('websocket closed'); }
      ws.onmessage = function(m) { show(m.data); };

        $(document).ready(function(){
          $("body").on("click", ".funtimes .tentical.extend", function(){
            link = $(this).parent(".funtimes").data("link")
            ws.send(JSON.stringify({extend: link}))
          })
        })

    })();
  }
