// Lambda function code
var AWS = require("aws-sdk");
// Set the AWS Region.
AWS.config.update({ region: "eu-west-1" });
// Create DynamoDB service object.
var docClient = new AWS.DynamoDB.DocumentClient();

module.exports.handler = async (event) => {
    console.log('Event: ', event);
    let responseMessage = 'Hello, from post todo!';
    let table = process.env.TODO_TABLE
    let todo = {};
  
    if (event.body) {
      body = JSON.parse(event.body);

      reqPk = body.PK;
      reqContent = body.content;
      reqCompleted = body.completed;

      todo = {
        "PK": reqPk,
        "content": reqContent,
        "completed": reqCompleted
      }

      var params = {
        TableName:table,
        Item: todo
    };
    
    console.log("Adding a new item...");
    res = await docClient.put(params).promise();
      
    }
  
    return {
      statusCode: 200,
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
      },
      body: JSON.stringify({
        message: responseMessage,
      }),
    }
  }
  