CREATE TABLE Machine (
  machine_id VARCHAR(40) PRIMARY KEY,
  description VARCHAR(40),
  line_id VARCHAR(40)
);

CREATE TABLE machine_state (
  machine_id VARCHAR(40),
  start_time TIMESTAMP,
  end_time TIMESTAMP,
  state VARCHAR(40),
  FOREIGN KEY (machine_id) REFERENCES Machine(machine_id)
);


CREATE TABLE SS_REJECT (
  LINE_id VARCHAR(40),
  INPUT_time TIMESTAMP
);

CREATE TABLE SS_GOOD (
  LINE_id VARCHAR(40),
  INPUT_time TIMESTAMP
);

DROP TABLE LOT;

CREATE TABLE lot (
  lot_id VARCHAR(40) PRIMARY KEY,
  LINE_ID VARCHAR(40),
	start_time TIMESTAMP,
  end_time TIMESTAMP,
  QTY_IN INTEGER,
	QTY_OUT INTEGER,
  QTY_REJ INTEGER
);

CREATE TABLE CALENDAR
(
  YEAR                     VARCHAR2(4 BYTE),
  WW                       VARCHAR2(2 BYTE),
  QUARTER                  NUMBER,
  MONTH                    NUMBER(10),
  STARTDATE                DATE,
  ENDDATE                  DATE
);

DROP TABLE MACHINE_TIME;

CREATE TABLE MACHINE_TIME
(
  MACHINE_ID            VARCHAR2(40),
  LINE_ID                     VARCHAR2(40),
  TXNDATE                  DATE,
  PROD_TIME                    NUMBER,
	DOWN_TIME  NUMBER
);



CREATE TABLE OEE
(
   LINE_ID              VARCHAR2(40),
  TXNDATE          DATE,
  WW                    INTEGER,
  QUARTER          INTEGER,
  YEAR                  INTEGER, 
  AVAIL                 INTEGER,
  PERF  NUMBER,
  QUAL  NUMBER,
  OEE  NUMBER
);

CREATE TABLE CONFIG
(
  TOTAL_TIME          NUMBER,
  SDOWN_TIME          NUMBER,
  IDEA_OUTPUT_RATING  NUMBER
);

