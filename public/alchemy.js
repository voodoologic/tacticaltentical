$(document).ready(function(){
    $('body').on("click", "div.toast button.visit, div.toast button.extend", function(){
      link = $(this).parent("div").data("link");
      if ($(this).attr("class").split(" ").indexOf("visit") > -1) {
        escape(window.open(link))
      } else if ($(this).attr("class").split(" ").indexOf("extend") > -1) {
        toastr.info("fetching the site, this may take a while.", {timeOut: 60000});
      }
    });
    alchemy.begin({
      dataSource: '/json',
      clusterColours: ["#1B9E77","#D95F02","#7570B3","#E7298A","#66A61E","#E6AB02"],
      curvedEdges: false,
      linkDistance: 5,
      nodeFilters: true,
      nodeTypes: {"role":["Site", "Participant", "Comment"]},
      edgeTypes: {"caption": ["Contains", "Referred by"]},
      nodeColour: "#CCC",
      collisionDetection: false,
      captionsToggle: true,
      search: true,
      nodeCaption: "caption",
      edgeCaption: "caption",
      nodeClick: function(node){
        if (node.getProperties("role") === "Site") {
          toastr['info']( node.getProperties("link") +
          "<div class='funtimes' data-link='" +
          node.getProperties("link") +
          "'><button class='btn btn-primary tentical visit'>visit</button>" + 
          "<button class='btn btn-primary tentical extend'>extend search</button></div>" 
          , "SITE");
        } else if ( node.getProperties("role") === "Participant" ) {
          window.open( node.getProperties("link") );
        } else if (node.getProperties("role") == "Comment") {
          toastr['info'](node.getProperities("text"))
        }
      },
      "nodeStyle": {
        "Site": {
          color: "#FFF",
          radius: 20
        },
        "Participant": {
          color: "#00EEEE",
    borderColor: "#2F4F4F"
        },
        "Comment": {
          color: "#8B008B"
        }
      },
      "edgeStyle": {
        "Contains": {
          color: "#fff",
          width: 10
        },
        "Referred by": {
          color: "#ff00f3",
          borderWidth: 10,
          width: 20
        }
      }
    })

    toastr.options = {
      "closeButton": true,
      "debug": false,
      "newestOnTop": false,
      "progressBar": true,
      "positionClass": "toast-top-right",
      "onclick": null,
      "showDuration": "300",
      "hideDuration": "1000",
      "timeOut": "50000",
      "extendedTimeOut": "10000",
      "showEasing": "swing",
      "hideEasing": "linear",
      "showMethod": "fadeIn",
      "hideMethod": "fadeOut"
    }
  });
