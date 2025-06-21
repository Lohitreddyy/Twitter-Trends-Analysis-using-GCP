
requirements.txt
      tweepy
      google-cloud-pubsub
      apache-beam[gcp]
      google-cloud-bigquery
      textblob


data_ingestion/
   └── twitter_to_pubsub.py
      Tweet Ingestion → Pub/Sub

      import tweepy
      from google.cloud import pubsub_v1
      import os
      import json
      
      #Environment setup
      BEARER_TOKEN = os.getenv("TWITTER_BEARER_TOKEN")
      PROJECT_ID = "your-project-id"
      TOPIC_ID = "twitter-topic"
      
      publisher = pubsub_v1.PublisherClient()
      topic_path = publisher.topic_path(PROJECT_ID, TOPIC_ID)
      
      class TweetStreamer(tweepy.StreamingClient):
          def on_tweet(self, tweet):
              if tweet.text.startswith("RT"):
                  return
              data = {
                  "id": tweet.id,
                  "text": tweet.text,
                  "created_at": str(tweet.created_at),
              }
              publisher.publish(topic_path, json.dumps(data).encode("utf-8"))
      
      if __name__ == "__main__":
          stream = TweetStreamer(BEARER_TOKEN)
          stream.add_rules(tweepy.StreamRule("lang:en"))
          stream.filter(tweet_fields=["created_at"])



  dataflow_pipeline/
      └── tweet_processing.py

      #dataflow_pipeline/tweet_processing.py
      import apache_beam as beam
      from apache_beam.options.pipeline_options import PipelineOptions
      from textblob import TextBlob
      import json
      
      class ParseTweet(beam.DoFn):
          def process(self, element):
              record = json.loads(element)
              text = record["text"]
              sentiment = TextBlob(text).sentiment.polarity
              yield {
                  "id": record["id"],
                  "text": text,
                  "created_at": record["created_at"],
                  "sentiment": sentiment
              }
      
      def run():
          options = PipelineOptions(
              streaming=True,
              project='your-project-id',
              region='your-region',
              job_name='tweet-analysis',
              temp_location='gs://your-bucket/temp',
              runner='DataflowRunner'
          )
      
          with beam.Pipeline(options=options) as p:
              (
                  p
                  | 'ReadFromPubSub' >> beam.io.ReadFromPubSub(topic='projects/your-project-id/topics/twitter-topic')
                  | 'ParseTweets' >> beam.ParDo(ParseTweet())
                  | 'WriteToBigQuery' >> beam.io.WriteToBigQuery(
                      table='your-project-id:dataset.tweets',
                      schema='id:INTEGER, text:STRING, created_at:TIMESTAMP, sentiment:FLOAT',
                      write_disposition=beam.io.BigQueryDisposition.WRITE_APPEND
                  )
              )
      
      if __name__ == "__main__":
          run()




bigquery/
   └── sentiment_model.sql
#//This is just an optional BigQuery ML; insert your project name, dataset

  CREATE OR REPLACE MODEL `your_project.dataset.sentiment_model` 
  OPTIONS(model_type='logistic_reg') AS
  SELECT
    sentiment > 0 AS label,
    ML.PREDICT(MODEL `your_project.dataset.sentiment_model`, 
      (SELECT text FROM `your_project.dataset.tweets` LIMIT 1000))
  FROM
    `your_project.dataset.tweets`
  WHERE
    text IS NOT NULL;
