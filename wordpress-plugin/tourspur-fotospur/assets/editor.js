/* Editor für den Block „Fotospur“ – ohne Build-Schritt, nur mit den WordPress-Paketen */
(function (wp) {
  "use strict";
  var el = wp.element.createElement;
  var Fragment = wp.element.Fragment;
  var be = wp.blockEditor;
  var c = wp.components;
  var useSelect = wp.data.useSelect;
  var ServerSideRender = wp.serverSideRender;

  function Edit(props) {
    var a = props.attributes;
    var set = props.setAttributes;
    var blockProps = be.useBlockProps();

    var gpx = useSelect(function (select) {
      return a.gpxId ? select("core").getMedia(a.gpxId) : null;
    }, [a.gpxId]);

    function gpxButton(label) {
      return el(be.MediaUpload, {
        allowedTypes: ["application/gpx+xml"],
        value: a.gpxId,
        onSelect: function (m) { set({ gpxId: m.id, name: a.name || (m.title || "").replace(/\.gpx$/i, "") }); },
        render: function (o) { return el(c.Button, { variant: a.gpxId ? "secondary" : "primary", onClick: o.open }, label); }
      });
    }
    function photoButton() {
      return el(be.MediaUpload, {
        allowedTypes: ["image"],
        multiple: true,
        gallery: true,
        value: a.imageIds,
        onSelect: function (list) { set({ imageIds: list.map(function (m) { return m.id; }) }); },
        render: function (o) {
          return el(c.Button, { variant: "secondary", onClick: o.open },
            a.imageIds.length ? "Fotos ändern (" + a.imageIds.length + ")" : "Fotos auswählen");
        }
      });
    }

    var controls = el(be.InspectorControls, null,
      el(c.PanelBody, { title: "Tour" },
        el(c.TextControl, { label: "Name der Tour", value: a.name, onChange: function (v) { set({ name: v }); } }),
        el("p", null, gpx ? "GPX: " + ((gpx.title && gpx.title.rendered) || gpx.source_url) : "Noch keine GPX-Datei."),
        el("div", { style: { display: "flex", gap: "8px", flexWrap: "wrap" } }, gpxButton("GPX-Datei ändern"), photoButton())
      )
    );

    if (!a.gpxId) {
      return el("div", blockProps,
        el(be.MediaUploadCheck, null,
          el(c.Placeholder, {
            icon: "location-alt",
            label: "Fotospur",
            instructions: "Wähle die GPX-Datei aus Tourspur und danach die Fotos der Tour. Wo jedes Foto auf der Strecke hingehört, liest der Block aus Uhrzeit und Ort im Foto."
          }, el("div", { style: { display: "flex", gap: "8px", flexWrap: "wrap" } }, gpxButton("GPX-Datei auswählen"), photoButton()))
        )
      );
    }

    return el(Fragment, null, controls,
      el("div", blockProps,
        el(be.BlockControls, null,
          el(c.ToolbarGroup, null,
            el(be.MediaUpload, {
              allowedTypes: ["image"], multiple: true, gallery: true, value: a.imageIds,
              onSelect: function (list) { set({ imageIds: list.map(function (m) { return m.id; }) }); },
              render: function (o) { return el(c.ToolbarButton, { onClick: o.open }, "Fotos"); }
            })
          )
        ),
        el(ServerSideRender, { block: props.name, attributes: a })
      )
    );
  }

  wp.blocks.registerBlockType("tourspur/fotospur", {
    edit: Edit,
    save: function () { return null; }
  });

  // Früherer Name: bestehende Beiträge bleiben bearbeitbar, neu einfügen lässt er sich nicht mehr.
  if (!wp.blocks.getBlockType("rollermomente/fotospur")) {
    wp.blocks.registerBlockType("rollermomente/fotospur", {
      title: "Fotospur (alt)",
      supports: { inserter: false, html: false },
      edit: Edit,
      save: function () { return null; }
    });
  }
})(window.wp);
