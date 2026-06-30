CREATE TABLE domains (
  id                    INTEGER PRIMARY KEY,
  name                  VARCHAR(255) NOT NULL,
  master                VARCHAR(128) DEFAULT NULL,
  last_check            INT DEFAULT NULL,
  type                  VARCHAR(6) NOT NULL,
  notified_serial       INT DEFAULT NULL,
  account               VARCHAR(40) DEFAULT NULL,
  options               VARCHAR(65535) DEFAULT NULL,
  catalog               VARCHAR(255) DEFAULT NULL
);

CREATE UNIQUE INDEX name_index ON domains(name);

CREATE TABLE records (
  id                    INTEGER PRIMARY KEY,
  domain_id             INT DEFAULT NULL,
  name                  VARCHAR(255) DEFAULT NULL,
  type                  VARCHAR(10) DEFAULT NULL,
  content               VARCHAR(65535) DEFAULT NULL,
  ttl                   INT DEFAULT NULL,
  prio                  INT DEFAULT NULL,
  disabled              BOOLEAN DEFAULT 0,
  ordername             VARCHAR(255),
  auth                  BOOL DEFAULT 1
);

CREATE INDEX rec_name_index ON records(name);
CREATE INDEX nametype_index ON records(name, type);
CREATE INDEX domain_id ON records(domain_id);

CREATE TABLE supermasters (
  ip                    VARCHAR(64) NOT NULL,
  nameserver            VARCHAR(255) NOT NULL,
  account               VARCHAR(40) NOT NULL,
  PRIMARY KEY(ip, nameserver)
);

CREATE TABLE comments (
  id                    INTEGER PRIMARY KEY,
  domain_id             INT NOT NULL,
  name                  VARCHAR(255) NOT NULL,
  type                  VARCHAR(10) NOT NULL,
  modified_at           INT NOT NULL,
  account               VARCHAR(40) DEFAULT NULL,
  comment               VARCHAR(65535) NOT NULL
);

CREATE INDEX comments_name_type_idx ON comments(name, type);
CREATE INDEX comments_order_idx ON comments(domain_id, modified_at);

CREATE TABLE domainmetadata (
  id                    INTEGER PRIMARY KEY,
  domain_id             INT NOT NULL,
  kind                  VARCHAR(32),
  content               TEXT
);

CREATE INDEX domainidmetaindex ON domainmetadata(domain_id);

CREATE TABLE cryptokeys (
  id                    INTEGER PRIMARY KEY,
  domain_id             INT NOT NULL,
  flags                 INT NOT NULL,
  active                BOOL,
  published             BOOL DEFAULT 1,
  content               TEXT
);

CREATE INDEX domainidindex ON cryptokeys(domain_id);

CREATE TABLE tsigkeys (
  id                    INTEGER PRIMARY KEY,
  name                  VARCHAR(255),
  algorithm             VARCHAR(50),
  secret                VARCHAR(255)
);

CREATE UNIQUE INDEX namealgoindex ON tsigkeys(name, algorithm);
