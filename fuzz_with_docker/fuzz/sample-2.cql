CREATE KEYSPACE Excalibur
           WITH replication = {'class': 'NetworkTopologyStrategy', 'DC1' : 1, 'DC2' : 3}
            AND durable_writes = false;
