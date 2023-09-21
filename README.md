Spark Glue Data Catalog Docker Image
-----------------
This repository contains a Docker image for Spark with AWS Glue Data Catalog configurations. The image is based on the official Apache Spark Docker image.

## Example

1. Set AWS credentials and region:

    ```bash
    export AWS_ACCESS_KEY_ID='<ACCESS_KEY_ID>'
    export AWS_SECRET_ACCESS_KEY='<SECRET_ACCESS_KEY>'
    export AWS_REGION='<REGION>'
    ```

    **Note:** The account should have permissions for AWS Glue Data Catalog and S3.

2. Start Spark shell with Delta Lake and AWS Glue Data Catalog configurations:

    ```bash
    spark-shell --packages io.delta:delta-core_2.12:2.4.0 \
      --conf "spark.jars.ivy=/tmp/ivy/cache" \
      --conf "spark.sql.extensions=io.delta.sql.DeltaSparkSessionExtension" \
      --conf "spark.sql.catalog.spark_catalog=org.apache.spark.sql.delta.catalog.DeltaCatalog" \
      --conf "spark.hadoop.hive.imetastoreclient.factory.class=com.amazonaws.glue.catalog.metastore.AWSGlueDataCatalogHiveClientFactory" \
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