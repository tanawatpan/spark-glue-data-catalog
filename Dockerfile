ARG SPARK_VERSION=3.5.0
ARG PYTHON_VERSION=3.11
ARG SCALA_VERSION=2.12
ARG DELTA_VERSION=3.0.0
ARG SPARK_PACKAGES="org.apache.spark:spark-hadoop-cloud_${SCALA_VERSION}:${SPARK_VERSION},io.delta:delta-spark_${SCALA_VERSION}:${DELTA_VERSION},org.apache.spark:spark-connect_${SCALA_VERSION}:${SPARK_VERSION}"
ARG PYTHON_PACKAGES="findspark regex pyarrow numpy scipy pandas nltk scikit-learn transformers"

FROM maven:3.9.6-eclipse-temurin-8 AS build
ARG SPARK_VERSION
ARG SCALA_VERSION

# Install required packages
RUN apt -y update \
 && apt -y install -y wget git patch \
 && apt -y clean

# Build patched Hive for Hive client
WORKDIR /src
RUN git clone --branch branch-3.1 https://github.com/apache/hive.git

# Build patched Hive
WORKDIR /src/hive
RUN git checkout branch-3.1 \
 && wget https://raw.githubusercontent.com/awslabs/aws-glue-data-catalog-client-for-apache-hive-metastore/branch-3.4.0/branch_3.1.patch \
 && git apply -3 branch_3.1.patch

# Exclude pentaho-aggdesigner and pentaho-aggdesigner-algorithm
RUN cat <<EOF > exclude
<exclusions>
    <exclusion>
        <groupId>org.pentaho</groupId>
        <artifactId>pentaho-aggdesigner</artifactId>
    </exclusion>
    <exclusion>
        <groupId>org.pentaho</groupId>
        <artifactId>pentaho-aggdesigner-algorithm</artifactId>
    </exclusion>
</exclusions>
EOF
RUN sed -i "82 r exclude" upgrade-acid/pom.xml

RUN mvn clean install -DskipTests

RUN git add . \
 && git reset --hard \
 && git checkout branch-2.3 \
 && wget https://issues.apache.org/jira/secure/attachment/12958418/HIVE-12679.branch-2.3.patch \
 && patch -p0 <HIVE-12679.branch-2.3.patch

# Shade commons-lang3, apache-parquet
RUN cat <<EOF > shade
<relocation>
    <pattern>org.apache.commons.lang3</pattern>
    <shadedPattern>shaded.org.apache.commons.lang3</shadedPattern>
</relocation>
<relocation>
    <pattern>org.apache.parquet</pattern>
    <shadedPattern>shaded.org.apache.parquet</shadedPattern>
</relocation>
EOF
RUN sed -i "933 r shade" ql/pom.xml

RUN mvn clean install -DskipTests

# Build AWS Glue Hive-Spark client
WORKDIR /src
RUN git clone --branch branch-3.4.0 https://github.com/awslabs/aws-glue-data-catalog-client-for-apache-hive-metastore.git
WORKDIR /src/aws-glue-data-catalog-client-for-apache-hive-metastore
RUN mvn clean package -DskipTests

# Build Spark
FROM apache/spark:${SPARK_VERSION}-scala${SCALA_VERSION}-java11-ubuntu
ARG SPARK_PACKAGES
ARG PYTHON_VERSION
ARG PYTHON_PACKAGES

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
 && pip${PYTHON_VERSION} install $PYTHON_PACKAGES

# Remove existing Hive jars
RUN rm -f $SPARK_HOME/jars/hive-exec-* \
 && rm -f $SPARK_HOME/jars/hive-common-* \
 && rm -f $SPARK_HOME/jars/hive-metastore-*

RUN mkdir -p /home/spark \
 && chown -R spark:spark /home/spark

USER spark
WORKDIR $SPARK_HOME/jars
# Copy patched Hive and AWS Glue Hive-Spark client jars
COPY --from=build /root/.m2/repository/org/apache/hive/hive-exec/2.3.10-SNAPSHOT/hive-exec-2.3.10-SNAPSHOT.jar ./
COPY --from=build /root/.m2/repository/org/apache/hive/hive-common/2.3.10-SNAPSHOT/hive-common-2.3.10-SNAPSHOT.jar ./
COPY --from=build /root/.m2/repository/org/apache/hive/hive-metastore/2.3.10-SNAPSHOT/hive-metastore-2.3.10-SNAPSHOT.jar ./
COPY --from=build /src/aws-glue-data-catalog-client-for-apache-hive-metastore/aws-glue-datacatalog-spark-client/target/aws-glue-datacatalog-spark-client-3.4.0-SNAPSHOT.jar ./

RUN $SPARK_HOME/bin/spark-submit --master local[1] \
  --class org.apache.spark.examples.SparkPi \
  --packages $SPARK_PACKAGES  \
  $SPARK_HOME/examples/jars/spark-examples_*.jar 4
RUN cp -f /home/spark/.ivy2/jars/*.jar $SPARK_HOME/jars/

ENV PATH=$PATH:$SPARK_HOME/bin:$SPARK_HOME/sbin
ENV PYSPARK_PYTHON=python${PYTHON_VERSION}
WORKDIR $SPARK_HOME