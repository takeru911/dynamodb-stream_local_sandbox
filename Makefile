MAKE=make -s
TABLE_NAME:=table
APP:=dynamodb
EX_PARAM:=--endpoint-url http://localhost:8000

setup:
	mkdir -p bin
	wget https://s3-ap-northeast-1.amazonaws.com/dynamodb-local-tokyo/dynamodb_local_latest.tar.gz -P bin/
	tar -xf bin/dynamodb_local_latest.tar.gz -C bin/
	rm bin/dynamodb_local_latest.tar.gz

dynamo/up:
	java -Djava.library.path=./bin/DynamoDBLocal_lib -jar bin/DynamoDBLocal.jar -sharedDb &
	touch db.up

dynamo/down: db.up
	ps ax | grep DynamoDB | grep -v "grep" | awk '{print $$1}' | xargs -Ip kill -9 p
#	-rm -f dp.up

dynamo/reset: dynamo/down shared-local-instance.db
	rm -f shared-local-instance.db

dynamo/cli: db.up aws/cli

dynamo/create-table: config/ddl.json
	$(MAKE) dynamo/cli COMMAND="create-table --cli-input-json file://config/ddl.json"

dynamo/insert-record:
	$(MAKE) aws/cli COMMAND="put-item --table-name $(TABLE_NAME) --item file://config/record.json"

dynamo/scan:
	$(MAKE) aws/cli COMMAND="scan --table-name $(TABLE_NAME)"

dynamo-stream/cli: db.up
	@$(MAKE) aws/cli APP=dynamodbstreams

dynamo-stream/arn:
	@$(MAKE) dynamo-stream/cli COMMAND="list-streams --table-name $(TABLE_NAME)" | jq ".Streams[0].StreamArn"

dynamo-stream/shard-id:
	@$(MAKE) dynamo-stream/cli COMMAND="describe-stream --stream-arn $(shell make dynamo-stream/arn)" | jq ".StreamDescription.Shards[0].ShardId"

dynamo-stream/shard-iterator:
	@$(MAKE) dynamo-stream/cli COMMAND="get-shard-iterator --stream-arn $(shell make dynamo-stream/arn) --shard-id $(shell make dynamo-stream/shard-id) --shard-iterator-type TRIM_HORIZON"\
| jq ".ShardIterator"

dynamo-stream/get-records:
	$(MAKE) dynamo-stream/cli COMMAND='get-records --shard-iterator $(shell make dynamo-stream/shard-iterator)'

aws/cli:
	@aws $(APP) $(COMMAND) $(EX_PARAM)
