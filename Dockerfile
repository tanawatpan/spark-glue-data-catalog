FROM maven:3.6.3-openjdk-8 AS build

# Install required packages
RUN apt-get -y update \
 && apt-get -y install -y wget git patch \
 && apt-get -y clean

# Build patched Hive for Hive client
WORKDIR /src
RUN git clone https://github.com/apache/hive.git

# Install required packages
WORKDIR /root/.m2/repository/org/pentaho/pentaho-aggdesigner-algorithm/5.1.5-jhyde/
RUN wget https://repository.mapr.com/nexus/content/groups/mapr-public/conjars/org/pentaho/pentaho-aggdesigner-algorithm/5.1.5-jhyde/pentaho-aggdesigner-algorithm-5.1.5-jhyde.pom \
 && wget https://repository.mapr.com/nexus/content/groups/mapr-public/conjars/org/pentaho/pentaho-aggdesigner-algorithm/5.1.5-jhyde/pentaho-aggdesigner-algorithm-5.1.5-jhyde.jar

WORKDIR /root/.m2/repository/org/pentaho/pentaho-aggdesigner/5.1.5-jhyde/
RUN wget https://repository.mapr.com/nexus/content/groups/mapr-public/conjars/org/pentaho/pentaho-aggdesigner/5.1.5-jhyde/pentaho-aggdesigner-5.1.5-jhyde.pom

# Build patched Hive and AWS Glue Hive-Spark client
WORKDIR /src/hive
RUN git checkout branch-3.1 \
 && wget https://raw.githubusercontent.com/awslabs/aws-glue-data-catalog-client-for-apache-hive-metastore/branch-3.4.0/branch_3.1.patch \
 && git apply -3 branch_3.1.patch \
 && mvn clean install -DskipTests

RUN git add . \
 && git reset --hard \
 && git checkout branch-2.3 \
 && wget https://issues.apache.org/jira/secure/attachment/12958418/HIVE-12679.branch-2.3.patch \
 && patch -p0 <HIVE-12679.branch-2.3.patch \
 && mvn clean install -DskipTests

WORKDIR /src
RUN git clone --branch branch-3.4.0 https://github.com/awslabs/aws-glue-data-catalog-client-for-apache-hive-metastore.git
WORKDIR /src/aws-glue-data-catalog-client-for-apache-hive-metastore
RUN mvn clean package -DskipTests

# Final stage
FROM apache/spark:3.4.1-scala2.12-java11-ubuntu

ARG PYTHON_VERSION=3.11

# Install Python
USER root
RUN apt update && apt upgrade -y \
 && apt install software-properties-common -y \
 && add-apt-repository ppa:deadsnakes/ppa \
 && apt -y update \
 && apt -y install -y curl python${PYTHON_VERSION} \
 && curl -sS https://bootstrap.pypa.io/get-pip.py | python${PYTHON_VERSION} \
 && apt -y clean \
 && rm -rf /var/lib/apt/lists/*

# Install Python packages
RUN pip${PYTHON_VERSION} install --upgrade pip \
 && pip${PYTHON_VERSION} install findspark regex pyarrow numpy scipy nltk pandas scikit-learn transformers

ARG HADOOP_VERSION=3.3.4

# Remove existing Hive jars
RUN rm -f $SPARK_HOME/jars/hive-exec-* \
 && rm -f $SPARK_HOME/jars/hive-common-* \
 && rm -f $SPARK_HOME/jars/hive-metastore-*

# Download required Hadoop and AWS SDK jars
WORKDIR $SPARK_HOME/jars
RUN wget https://repo1.maven.org/maven2/org/apache/hadoop/hadoop-aws/${HADOOP_VERSION}/hadoop-aws-${HADOOP_VERSION}.jar \
 && wget https://repo1.maven.org/maven2/com/amazonaws/aws-java-sdk-bundle/1.12.537/aws-java-sdk-bundle-1.12.537.jar \
 && wget https://repo1.maven.org/maven2/org/apache/spark/spark-hadoop-cloud_2.12/3.4.1/spark-hadoop-cloud_2.12-3.4.1.jar

# Copy patched Hive and Hive client jars
COPY --from=build /root/.m2/repository/org/apache/hive/hive-exec/2.3.10-SNAPSHOT/hive-exec-2.3.10-SNAPSHOT.jar ./
COPY --from=build /root/.m2/repository/org/apache/hive/hive-common/2.3.10-SNAPSHOT/hive-common-2.3.10-SNAPSHOT.jar ./
COPY --from=build /root/.m2/repository/org/apache/hive/hive-metastore/2.3.10-SNAPSHOT/hive-metastore-2.3.10-SNAPSHOT.jar ./
COPY --from=build /src/aws-glue-data-catalog-client-for-apache-hive-metastore/aws-glue-datacatalog-spark-client/target/aws-glue-datacatalog-spark-client-3.4.0-SNAPSHOT.jar ./

USER spark
ENV PATH=$PATH:$SPARK_HOME/bin
ENV PYSPARK_PYTHON=python${PYTHON_VERSION}
WORKDIR $SPARK_HOME