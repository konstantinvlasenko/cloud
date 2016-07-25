'use strict';
var AWS = require("aws-sdk");
AWS.config.apiVersions = { cloudfront: '2016-01-28' };
var cloudfront = new AWS.CloudFront();

exports.handler = (event, context, callback) => {
    let _bucketName = event.Records[0].s3.bucket.name; // we assume all events originated from the same bucket
    getDistributionId(_bucketName, (err, id) => {
        if (err) callback(err);
        else {
            createInvalidation(id, context.awsRequestId, event.Records, (err) => {
                if (err) callback(err);
                else callback();
            });
        }
    });
};

function getDistributionId(bucketName, callback){
    cloudfront.listDistributions({}, (err, data) => {
        if (err) callback(err);
        else {
            let _distributions = data.Items.filter((distr) => {
                return distr.Origins.Items.filter((orig) => {
                    return orig.DomainName === bucketName + '.s3.amazonaws.com';
                }) !== [];
            });
            if(_distributions.length === 0) callback('Check if CloudFront distribution for S3 bucket ' + bucketName + ' has been created');
            else callback(null, _distributions[0].Id); // in theory an S3 bucket can participate in the several CloudFront distributions. But we'll support only one to one relation for now
        }
    });
}

function createInvalidation(DistributionId, CallerReference, records, callback){
    let _items = records.map((rec) => {
        return '/' + rec.s3.object.key;
    });
    let _params = {
        DistributionId: DistributionId,
        InvalidationBatch: {
            CallerReference: CallerReference,
            Paths: {
                Quantity: _items.length,
                Items: _items
            }
        }
    };
    cloudfront.createInvalidation(_params, function(err, data) {
        if (err) callback(err);
        else callback();
    });
}