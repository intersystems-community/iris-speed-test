### Common Questions and Answers

### 1 - How does this benchmark compare against standard benchmarks such as sysbench, YCSB or TPC-H?

The open source [sysbench](https://github.com/akopytov/sysbench) tool can certainly be extended but as of now it can only be used to test MySQL, PostgreSQL and other databases that are based on MySQL (ex.: AWS Aurora) or implement MySQL wire protocol. We could certainly modify it to test other databases but we wanted to use JDBC (not the C based driver that sysbench is using) and we needed the tool to be less dependent of the backend database for metrics collection. 

Our tests are also simpler in the sense that we only have one single table. **sysbench** allows you to run INSERTS and SELECTS in parallel, **in multiple copies of the same table** which is not fair for our use case. We want to test how efficient the database engine is with the same available IOPS on a single table. How does it deal with lock contention and memory caching. We could certainly using Sharding on InterSystems IRIS, which, in a sense, is liking allowing INSERTS and SELECTS to ocurr in parallel in multiple copies of the data. But then they would be running on different nodes, with more available IOPS, which would not be fair to sysbench. Finally, real applications don't generally keep multiples copies of the same table and when they do, most transactions and searches happen on the "master copy" while the other copies just hold historical data. So we think that sysbench is more oriented at testing the infrastructure setup, not the database itself.

The open-source Yahoo Cloud Serving Benchmark ([YCSB](https://en.wikipedia.org/wiki/YCSB)) project aims to develop a framework and common set of workloads for evaluating the performance of different “key-value” and “cloud” serving stores. 

Although there are workloads on YCSB that could be described as HTAP, YCSB doesn't necessarily rely on SQL to do it. This benchmark does.

TPC-H is focused on decision support systems (DSS) and that is not the use case we are exploring. 

On financial services applications (for example), data is coming in fast into a single table and how the data base deals with lock contention, **out of memory pressure** (blue on the diagram), and **in memory pressure** (yellow on the diagram). Lock contention issues is also critical. Allowing the test to be run on multiple tables (like sysbench) mitigates the lock contention problem and masks it. We don't want that. So we are running on a single node and a single table so we can really measure the database efficiency and memory caching intelligence.

The next diagram shows what we mean by **out of memory pressure** and **in memory pressure**:

![Memory Pressure x Query Pressure](https://raw.githubusercontent.com/intersystems-community/irisdemo-demo-htap/master/database-architecture.png?raw=true)

On the left, you can see data coming in fast, probably through several JDBC/ODBC connections. In order to provide Durability (see [ACID](https://en.wikipedia.org/wiki/ACID)), databases will immediately write the new transaction to a sequential log file (also known as journal) on disk. In a simplistic view, that is the only requirement for a succesful COMMIT and for the data to be considered "durable". Both traditional database and in-memory database do this (unless it is a pure in-memory database, which is out of the scope of this test). 

Databases will also keep this data in memory as a **memory cache**, as long as possible so that queries for this data can be answered very fast, without having to read data from disk. What is kept in memory is the **current state** of the database. For instance, many updates may have happened to a database row. The database log has all these updates. **The current state of the database is the cummulative result of all these updates**. The current state is the final truth. Both types of database (traditional and in-memory) will do their best to keep the current state of the database entirely in memory so that queries can be done very fast. 

Traditional databases will then do their best to write the current state in a structured **database file**. This is a slow process since the database has to update specific blocks on the database file to reflect the changes happening to the current state (random writes). Traditional databases will do this asynchronously as soon as possible. This has the advantage that, in case you need to restart your database, the current state of the database can be read directly from the database file (and completed with just a few records from the log file) instead of being reconstructed transaction by transaction entirely from the database log file.

In-Memory databases, on the other hand, will only write to the database file if they can't hold the full database state in memory any longer. They will apply data compression in memory as well to make the best usage of available memory. Some in-memory databases will not even have a database file to write to, relying completely on the log file when it is time to restart the database. These In-memory databases will crash if they run out of memory. But most enterprise In-Memory databases such as SAP HANA will write to the database file just like InterSystems IRIS does, but only when they are running out of memory and data compression doesn't help anymore.

So, as you can realize, if we are constantly inserting records (Data ingestion) to the database, there is a **out of memory pressure** building up, in order to open up more space in memory for the new records which will force these databases to write to disk. On the other hand, we are running parallel queries as well for a specifc set of records which will force the database to try their best to keep those constantly requested records in memory. That is what we call **in-memory pressure**.

We want to measure how fast a database can ingest the records while, at the same time, allowing for responsive queries:
* The table has just one table with 19 columns and 3 very different data types
* The table has a Primary Key declared on it.
* The queries we do, fetch records by the Primary Key (account id), with fixed 8 keys we query for randomly: W1A1, W1A10, W1A100, W1A1000, W1A10000, W1A100000, W1A1000000 and W1A10000000. Here is why we do this:
  * We know it is impossible to hold all data in memory in production systems. Even In memory databases have complex architectures that will move data out of memory when they are running out of it. To make the test simple and comparable, we are fetching this fixed set of records by primary key in order to avoid comparing different types of indices that databases may have. 
  * Fetching customer account data records by account number (PK) is a real workload that is happening in many of our customers. While data is being ingested at high speeds, the database needs to be responsive for queries. 
  * As the account id is a primary key, it will be indexed by the database using its preferred (and supposedly optimal) index for it. That will allow us to be fair when comparing the databases, while keeping this simple. 
  * The database will be given the opportunity to cache this data in memory as we are asking for the same account numbers over and over. We thought that would be an easy task for In Memory databases.

InterSystems IRIS is a hybrid database. As with traditional databases, it will also try to keep data in memory. But as thousands of records por second are coming in fast due to the ingestion work, the memory is purged very fast. This test allows you to see how InterSystems IRIS is smart about its cache when compared to other traditional databases and In Memory databases. You will see that:
* Traditional databases will perform poorly at ingestion and query
* In Memory databases will:
  * Perform well at ingestion during the first minutes of the test as memory fills up, compression becomes harder and writing to disk becomes unavoidable
  * Perform poorly at querying since the system will be too busy with ingestion, compressing data, moving data out of memory, etc. 

### 2 - Can I see the table?

Here is the the statement we send to all databases we support:

```SQL
CREATE TABLE SpeedTest.Account
(
    account_id VARCHAR(36) PRIMARY KEY,
    brokerageaccountnum VARCHAR(16),
    org VARCHAR(50),
    status VARCHAR(10),
    tradingflag VARCHAR(10),
    entityaccountnum VARCHAR(16),
    clientaccountnum VARCHAR(16),
    active_date DATETIME,
    topaccountnum VARCHAR(10),
    repteamno VARCHAR(8),
    repteamname VARCHAR(50),
    office_name VARCHAR(50),
    region VARCHAR(50),
    basecurr VARCHAR(50),
    createdby VARCHAR(50),
    createdts DATETIME,
    group_id VARCHAR(50),
    load_version_no BIGINT  
)
```

The Ingestion Worker will send as many INSERTs as possible as measure the number of records/sec inserted as well as the number of Megabytes/sec. 

The Query Worker will SELECT from this table by account_id and try to select as many records as possible measuring it as records/sec selected as well as Megabytes/sec select to test the **end-to-end performance** and to provide **proof of work**.

End-to-end performance has to do with the fact that some JDBC drivers have optmizations. If you just execute the query, the JDBC driver may not fetch the record from the server until you actually request for a value of a column. 

To prove that we are actually reading the columns we are SELECTing, we sum up the bytes of all the filds reeturned as **proof of work**.

### 3 - How do you achieve maximum throughput on ingestion and querying?

To achieve maximum throughput, each ingestion worker will start multiple threads that will each:
- Prepare a set of 1000 random values for each column of the table above. This is done because each column can have a different data type and a different size. So we want to genererate records that can vary accordingly
- For each new record to be inserted, the ingestion worker will randomly select one value out of the 1000 values for each column and once a record is ready, it will be added to the batch
- Use batch inserting with a default batch size of 1000 records per batch

The default number of ingestion worker threads is 15. But it can be changed during the test by clicking at the **Settings** button.

The query workers, on the other hand, also start multiple threads to query as many records as possible. But as we explained above, we are also providing **proof of work**. We are reading the columns returned and summing up the number of bytes read to make sure the data is actually traveling from the database, through the wire and into the query worker. That is to avoid optimizations implemented by some JDBC drivers that will only bring the data over the wire if it is actually used. We are actually consuming the data returned and providing a sum of MB read/s and total number of MB read as proof of it.

### 4 - How much space does InterSystems IRIS take on disk?

I filled up a 70Gb DATA file system after ingesting 171,421,000 records. That would mean that each record would take an average of 439 bytes (rounding up).

I also filled 100% of my first journal directory and about 59% of the second. Both filesystems had 100Gb which means that 171,421,000 would take about 159Gb of journal space or that each record would take an average of 996 bytes. 

### 5 - Architecture of the HTAP Demo

The architecture of the HTAP demo is shown below:

![Demo Landing Page](https://raw.githubusercontent.com/intersystems-community/irisdemo-demo-htap/master/README.png?raw=true)

This demo uses docker compose to start five services:

* **htapui** - this is the Angular UI you use to run the demo.
* **htapirisdb** - since the demo is running on InterSystems IRIS Community, you don't need an InterSystems IRIS license to run it. But be aware that InterSystems IRIS Community has two important limitations:
  * Max of 5 connections
  * Max Database size of 10Gb
* **htapmaster** - This is the HTAP Demo master. The UI talks to it and it talks to the workers to start/stop the speed test and collect metrics.
* **ingest-worker1** - This is an ingestion worker. You can actually have more than one ingestion worker; just give each one a different service name. They will try to INSERT records into the database as fast as possible.
* **query-worker1** - This is the consumption worker. You can have more than one of these as well. They will try to read records out of the database as fast as possible.

When running the demo on our PCs, we use Docker and Docker Compose. Docker Compose expects a **docker-compose.yml** that describes these services and the docker images they use. This demo actually provides many docker-compose.yml files and more will be added soon:
* **docker-compose.yml** - This is the default demo that runs the speed test against InterSystems IRIS Community described on the bullets and picture above.
* **docker-compose-mysql.yml** - This is the speed test against MySQL. 
* **docker-compose-sqlserver.yml** - This is the speed test against SqlServer.
* **docker-compose-postgres.yml** - This is the speed test against PostgreSQL. 


### 6 - Can I run this without containers against a random InterSystems IRIS Cluster?

Yes! The easiest way to get this done is to clone this repo on each server where you are planning on running the master and the UI (they run on the same server) and on each worker type (ingestion and query workers). You may have as many ingestion workers and query workers as you want! 

Then, for InterSystems IRIS, look at the files on folder [./standalone_scripts/iris-jdbc](https://github.com/intersystems-community/irisdemo-demo-htap/tree/master/standalone_scripts/iris-jdbc). There is a script for every server:
* **On the Master**: start_master_and_ui.sh - This script will start both the master and the UI.
* **On the Ingestion Workers**: start_ingestion_worker.sh - This script will start the ingestion worker which in turn will connect and register with the master.
* **On the Query Workers**: start_query_worker.sh - This script will start the query worker which in turn will connect and register with the master.

What about InterSystems IRIS? 
* You can use the start_iris.sh script to start an InterSystems IRIS server on a docker container for a quick test.

Just make sure you change your start_master.sh script to configure the environment variables with the correct InterSystems IRIS end points, usernames and passwords.

### 7 - Customizations

#### 7.1 - How do I configure this demo to run with more workers, threads, etc?

Look at the docker-compose.yml file and you will notice environment variables that will allow you to configure everything. The provided docker-compose yml files are just good starting points. You can copy them and change your copies to have more workers (it won't make a lot of difference if you are running on your PC), higher number of threads per worker type, change the ingestion batch size, wait time in milliseconds between queries on the consumter, etc.

#### 7.2 - Can I change the table name or structure?

Yes, but you will have to:
* Fork this repo on your PC
* Change the source code
* Rebuild the demo on your PC using the shellscript build.sh.

Changing the table structure should be simple. 

After forking, you need to change the files on folder [/image-master/projects/master/src/main/resources](https://github.com/intersystems-community/irisdemo-demo-htap/tree/master/image-master/projects/master/src/main/resources).

If you change the TABLE structure, make sure you use the same data types I am using on the existing table. Those are the data types supported. You can also change the name of the table. 

Then, change the other *.sql scripts to match your changes. The INSERT script, the SELECT script, etc.

Finally, just run the build.sh to rebuild the demo and you should be ready to go!

### 8 - Documentation about the columns on the Results CSV file

After running a test, the UI will allow you to download the test results as a CSV file. Here is what the columns on the Results CSV file mean:
* Ingestion:
  - **timeInSeconds** - A point in time during the test given in seconds.
  - **numberOfActiveIngestionThreads** - The total number of active ingestion threads sending data to the database.
  - **numberOfRowsIngested** - Total number of records inserted at a given point in time
  - **recordsIngestedPerSec** - Instantaneous ingestion rate expressed in number of records inserted per second (rec/s) at a given point in time. 
  - **avgRecordsIngestedPerSec** - Average number of records inserted per second up to a given point in time considering all records inserted up to that point in time.
  - **MBIngested** - Total amount of MB (mega bytes) inserted into the database at a given point in time
  - **MBIngestedPerSec** - Instantaneous ingestion rate expressed in amount of MB per second (MB/s) inserted at a given point in time.
  - **avgMBIngestedPerSec** - Average number of records inserted per second at a given point in time considering all records inserted up to that point in time.
* Querying:
  - **numberOfRowsConsumed** - Total number of records fetched from the database at a given point in time
  - **numberOfActiveQueryThreads** - The total number of active query threads fetching data from the database.
  - **recordsConsumedPerSec** Instantaneous query rate expressed in number of records fetched per second (rec/s) at a given point in time. 
  - **avgRecordsConsumedPerSec** - Average number of records fetched per second at a given point in time considering all records fetched up to that point in time.
  - **MBConsumed** - Total amount of MB (mega bytes) fetched from the database at a given point in time (as proof of work done by the querying workers)
  - **MBConsumedPerSec** - Instantaneous querying rate expressed in amount of MB per second (MB/s) fetched at a given point in time.
  - **avgMBConsumedPerSec** - Average number of records fetched per second at a given point in time considering all records fetched up to that point in time.
  - **queryAndConsumptionTimeInMs** - Instantaneous time taken to fetch a single record from the database and process it (sum the number of bytes fetched) measured in milliseconds.
  - **avgQueryAndConsumptionTimeInMs** - Average time taken to fetch a single record form the database and process it considering the total number of records fetched and how long the test has been running in milliseconds.

### 9 - Other demo applications

There are other InterSystems IRIS demo applications that touch different subjects such as NLP, ML, Integration with AWS services, Twitter services, performance benchmarks etc. Here are some of them:
* [HTAP Demo](https://github.com/intersystems-community/irisdemo-demo-htap) - Hybrid Transaction-Analytical Processing benchmark. See how fast InterSystems IRIS can insert and query at the same time. You will notice it is up to 20x faster than AWS Aurora!
* [Kafka Retail Banking Demo](https://github.com/intersystems-community/irisdemo-demo-kafka) - Shows how InterSystems IRIS can be used to import AVRO Schemas from a Kafka's schema registry and consume Kafka events from a simulated retail banking application. It shows how InterSystems IRIS can be used to collate the events into a canonical model, apply data transformation and vocabulary normalization and bring people into the process when issues appear. 
* [Fraud Prevention](https://github.com/intersystems-community/irisdemo-demo-fraudprevention) - Apply Machine Learning and Business Rules to prevent frauds in financial services transactions using InterSystems IRIS.
* [Twitter Sentiment Analysis](https://github.com/intersystems-community/irisdemo-demo-twittersentiment) - Shows how InterSystems IRIS can be used to consume Tweets in realtime and use its NLP (natural language processing) and business rules capabilities to evaluate the tweet's sentiment and the metadata to make decisions on when to contact someone to offer support.
* [HL7 Appointments and SMS (text messages) application](https://github.com/intersystems-community/irisdemo-demo-appointmentsms) -  Shows how InterSystems IRIS for Health can be used to parse HL7 appointment messages to send SMS (text messages) appointment reminders to patients. It also shows real time dashboards based on appointments data stored in a normalized data lake.
* [The Readmission Demo](https://github.com/intersystems-community/irisdemo-demo-readmission) - Patient Readmissions are said to be the "Hello World of Machine Learning" in Healthcare. On this demo, we use this problem to show how InterSystems IRIS can be used to **safely build and operationalize** ML models for real time predictions and how this can be integrated into a random application. This **InterSystems IRIS for Health** demo seeks to show how a full solution for this problem can be built.

### 10 - Supported Databases

Here is the list of the supported databases so far:
  - InterSystems IRIS 2024.3
  - MySQL 9.1.0
  - MS SQL Server 2022
  - Postgres 14

### 11 - Report any Issues
  
Please, report any issues on the [Issues section](https://github.com/intersystems-community/irisdemo-demo-htap/issues).

### 12 - Check the Change Log

All the changes to this project are logged [here](CHANGELOG.md).
