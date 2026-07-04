Place your Overpass API export here as osm.json

Query example for Meridian, ID:
[out:json];
(
  way["building"](around:200,43.6057601,-116.3932135);
  way["highway"](around:200,43.6057601,-116.3932135);
  way["leisure"="park"](around:200,43.6057601,-116.3932135);
  way["natural"="water"](around:200,43.6057601,-116.3932135);
);
out body;
>;
out geom;
