ALTER TABLE addamsFamily ALTER lastKnownLocation TYPE uuid;

ALTER TABLE addamsFamily ADD gravesite varchar;

ALTER TABLE addamsFamily
       WITH comment = 'A most excellent and useful table'
       AND read_repair_chance = 0.2;
