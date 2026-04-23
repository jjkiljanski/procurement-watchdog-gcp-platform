# Cloud Workflows — Daily Pipeline
#
# Rendered by Terraform templatefile(). Static config is baked in at apply time.
# Only `target_date` is a runtime arg (defaults to yesterday if omitted).
#
# Trigger manually for a specific date:
#   gcloud workflows run ${workflow_name} --location=${region} \
#     --data='{"target_date":"2025-03-15"}'
#
# The googleapis connectors below automatically poll long-running operations:
#   - run.v2 jobs.run   → waits for the Cloud Run Job execution to finish
#   - dataproc.v1 batches.create → waits for the full Spark batch to finish
#
# $${...} = Cloud Workflows expression (becomes ${...} in final YAML)
# ${...}  = Terraform template variable (resolved at terraform apply time)

main:
  params: [args]
  steps:

    - init:
        assign:
          - project_id: "${project_id}"
          - region: "${region}"
          - lakehouse_bucket: "${lakehouse_bucket}"
          - dataproc_sa: "${pipeline_sa_email}"
          - dataproc_subnet: "${dataproc_subnet_self_link}"
          - dataproc_image: "${dataproc_container_image}"
          - jobs_gcs_prefix: "gs://${lakehouse_bucket}/jobs"
          - downloader_job: "${downloader_job_name}"
          - bq_dataset: "${bq_silver_dataset_id}"
          - bq_obs_dataset: "${bq_obs_dataset_id}"

    - resolve_date:
        assign:
          - target_date: $${default(map.get(args, "target_date"), text.substring(time.format(sys.now() - 86400), 0, 10))}

    - guard_image:
        switch:
          - condition: $${dataproc_image == ""}
            raise: "dataproc_container_image is not set. Build and push procurement-spark, then update the Terraform variable."

    - log_start:
        call: sys.log
        args:
          text: $${"[pipeline] starting for date=" + target_date}
          severity: INFO

    # ---------------------------------------------------------------------- #
    # Step 1 — Download: fetch BZP API data for target_date
    # ---------------------------------------------------------------------- #

    - step_1_download:
        call: googleapis.run.v2.projects.locations.jobs.run
        args:
          name: $${"projects/" + project_id + "/locations/" + region + "/jobs/" + downloader_job}
          body:
            overrides:
              containerOverrides:
                - env:
                    - name: TARGET_DATE
                      value: $${target_date}
        connector_params:
          timeout: 3600
        result: download_result

    - log_download_done:
        call: sys.log
        args:
          text: $${"[pipeline] download complete for date=" + target_date}
          severity: INFO

    # ---------------------------------------------------------------------- #
    # Step 2 — Bronze: validate raw JSON, write partitioned Parquet
    # ---------------------------------------------------------------------- #

    - step_2_bronze:
        call: submit_batch
        args:
          project_id: $${project_id}
          region: $${region}
          script_path: $${jobs_gcs_prefix + "/build_bronze.py"}
          target_date: $${target_date}
          lakehouse_bucket: $${lakehouse_bucket}
          dataproc_sa: $${dataproc_sa}
          dataproc_subnet: $${dataproc_subnet}
          dataproc_image: $${dataproc_image}
        result: bronze_result

    - log_bronze_done:
        call: sys.log
        args:
          text: $${"[pipeline] bronze complete for date=" + target_date}
          severity: INFO

    # ---------------------------------------------------------------------- #
    # Step 3 — Silver: HTML parsing → Iceberg tables
    # ---------------------------------------------------------------------- #

    - step_3_silver:
        call: submit_batch
        args:
          project_id: $${project_id}
          region: $${region}
          script_path: $${jobs_gcs_prefix + "/build_silver_day.py"}
          target_date: $${target_date}
          lakehouse_bucket: $${lakehouse_bucket}
          dataproc_sa: $${dataproc_sa}
          dataproc_subnet: $${dataproc_subnet}
          dataproc_image: $${dataproc_image}
        result: silver_result

    - log_silver_done:
        call: sys.log
        args:
          text: $${"[pipeline] silver complete for date=" + target_date}
          severity: INFO

    # ---------------------------------------------------------------------- #
    # Step 4 — Deltas: extract change records from NoticeUpdateNotice
    # ---------------------------------------------------------------------- #

    - step_4_deltas:
        call: submit_batch
        args:
          project_id: $${project_id}
          region: $${region}
          script_path: $${jobs_gcs_prefix + "/build_silver_update_deltas.py"}
          target_date: $${target_date}
          lakehouse_bucket: $${lakehouse_bucket}
          dataproc_sa: $${dataproc_sa}
          dataproc_subnet: $${dataproc_subnet}
          dataproc_image: $${dataproc_image}
        result: deltas_result

    - done:
        steps:
          - log_done:
              call: sys.log
              args:
                text: $${"[pipeline] all steps complete for date=" + target_date}
                severity: INFO
          - return_result:
              return:
                status: ok
                date: $${target_date}


# --------------------------------------------------------------------------- #
# Sub-workflow: submit a Dataproc Serverless PySpark batch and wait for it
#
# Uses googleapis connector which auto-polls the LRO until the batch reaches
# SUCCEEDED or FAILED, then returns or raises.
# --------------------------------------------------------------------------- #

submit_batch:
  params: [project_id, region, script_path, target_date, lakehouse_bucket, dataproc_sa, dataproc_subnet, dataproc_image]
  steps:
    - run_batch:
        call: googleapis.dataproc.v1.projects.regions.batches.create
        args:
          parent: $${"projects/" + project_id + "/regions/" + region}
          body:
            pysparkBatch:
              mainPythonFileUri: $${script_path}
              args:
                - $${"--date=" + target_date}
              jarFileUris:
                - file:///opt/iceberg-spark-runtime.jar
            environmentConfig:
              executionConfig:
                serviceAccount: $${dataproc_sa}
                subnetworkUri: $${dataproc_subnet}
            runtimeConfig:
              containerImage: $${dataproc_image}
              properties:
                "spark.kubernetes.driverEnv.RUNTIME_ENV": gcp
                "spark.kubernetes.driverEnv.LAKEHOUSE_BUCKET": $${lakehouse_bucket}
                "spark.kubernetes.driverEnv.GCP_PROJECT": $${project_id}
                "spark.kubernetes.driverEnv.DATAPROC_REGION": $${region}
                "spark.executorEnv.RUNTIME_ENV": gcp
                "spark.executorEnv.LAKEHOUSE_BUCKET": $${lakehouse_bucket}
                "spark.executorEnv.GCP_PROJECT": $${project_id}
                "spark.executorEnv.DATAPROC_REGION": $${region}
        connector_params:
          timeout: 7200
          polling_policy:
            initial_delay: 30
            multiplier: 1.5
            max_delay: 120
        result: batch_result
    - return_result:
        return: $${batch_result}
