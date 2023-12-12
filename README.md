Spark Glue Data Catalog Docker Image
-----------------
This repository contains a Docker image for Spark with AWS Glue Data Catalog configurations. The image is based on the official Apache Spark Docker image.

## Build Image

1. Clone the repository:

    ```bash
    git clone https://github.com/tanawatpan/spark-glue-data-catalog.git
    cd <repository_directory>
    ```

2. Set up build arguments via environment variables:

    ```bash
    export SPARK_VERSION=3.5.0
    export DELTA_VERSION=3.0.0
    export SCALA_VERSION=2.12
    export PYTHON_VERSION=3.11
    export PYTHON_PACKAGES="findspark regex pyarrow numpy scipy pandas nltk scikit-learn transformers"
    ```

3. Build the Docker image:

    ```bash
    docker build --platform linux/amd64 \
      --build-arg SPARK_VERSION \
      --build-arg DELTA_VERSION \
      --build-arg SCALA_VERSION \
      --build-arg PYTHON_VERSION \
      --build-arg PYTHON_PACKAGES \
      -t spark:${SPARK_VERSION} .
    ```

## Example Usage

1. Set AWS credentials and region:

    ```bash
    export AWS_ACCESS_KEY_ID='<ACCESS_KEY_ID>'
    export AWS_SECRET_ACCESS_KEY='<SECRET_ACCESS_KEY>'
    export AWS_REGION='<REGION>'
    ```

    **Note:** The account should have permissions for AWS Glue Data Catalog and S3.

2. Start Spark shell with Delta Lake and AWS Glue Data Catalog configurations:

    ```bash
    spark-shell --conf "spark.hadoop.hive.imetastoreclient.factory.class=com.amazonaws.glue.catalog.metastore.AWSGlueDataCatalogHiveClientFactory" \
      --conf "spark.sql.catalog.spark_catalog=org.apache.spark.sql.delta.catalog.DeltaCatalog" \
      --conf "spark.sql.extensions=io.delta.sql.DeltaSparkSessionExtension" \
      --conf "spark.sql.catalogImplementation=hive" \
      --conf "spark.hadoop.fs.s3.impl=org.apache.hadoop.fs.s3a.S3AFileSystem" \
      --conf "spark.hadoop.fs.s3a.impl=org.apache.hadoop.fs.s3a.S3AFileSystem" \
      --conf "spark.hadoop.aws.region=$AWS_REGION" \
      --conf "spark.hadoop.fs.s3a.access.key=$AWS_ACCESS_KEY_ID" \
      --conf "spark.hadoop.fs.s3a.secret.key=$AWS_SECRET_ACCESS_KEY" \
      --conf "spark.hadoop.fs.s3a.path.style.access=true" \
      --conf "spark.hadoop.fs.s3a.connection.ssl.enabled=true"
    ```

    **Note:** According to [HIVE-12679](https://issues.apache.org/jira/secure/attachment/12958418/HIVE-12679.branch-2.3.patch), use `hive.imetastoreclient.factory.class` instead of `hive.metastore.client.factory.class`.

3. Run a Spark SQL query to show Glue Catalog Databases:

    ```scala
    > spark.sql("show databases").show()
    ```