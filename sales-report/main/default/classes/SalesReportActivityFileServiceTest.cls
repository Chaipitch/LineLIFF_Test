@IsTest
private class SalesReportActivityFileServiceTest {
  private static final String TASK_ID = '00T000000000001EAA';

  private static SalesReportOrgApiCalloutService api() {
    return new SalesReportOrgApiCalloutService(
      'session-token',
      'Asia/Bangkok',
      UserInfo.getUserId()
    );
  }

  private static SalesReportException attachExpectingFailure(
    String taskId,
    String name,
    Blob data
  ) {
    try {
      new SalesReportActivityFileService().attach(api(), taskId, name, data);
    } catch (SalesReportException e) {
      return e;
    }
    Assert.fail('Expected a SalesReportException');
    return null;
  }

  @IsTest
  static void photoIsUploadedToTheTaskAsTheRep() {
    SalesReportHttpMock http = SalesReportTestFactory.taskFileMock(
      UserInfo.getUserId(),
      Datetime.now(),
      1
    );
    Test.setMock(HttpCalloutMock.class, http);

    Test.startTest();
    SalesReportActivityFileData result = new SalesReportActivityFileService()
      .attach(api(), TASK_ID, 'IMG_0001.jpg', Blob.valueOf('jpeg-bytes'));
    Test.stopTest();

    Assert.areEqual('068000000000001AAA', result.id, 'ContentVersion ID');
    Assert.areEqual('IMG_0001.jpg', result.name, 'Name');
    Assert.areEqual(10, result.size, 'Bytes');
    Map<String, Object> sent = (Map<String, Object>) JSON.deserializeUntyped(
      http.lastRequest.getBody()
    );
    Assert.areEqual(TASK_ID, sent.get('FirstPublishLocationId'), 'On the Task');
    Assert.areEqual('IMG_0001', sent.get('Title'), 'Title');
    Assert.areEqual(
      EncodingUtil.base64Encode(Blob.valueOf('jpeg-bytes')),
      sent.get('VersionData'),
      'Content'
    );
    Assert.areEqual(
      'Bearer session-token',
      http.lastRequest.getHeader('Authorization'),
      'Uploaded as the rep'
    );
  }

  @IsTest
  static void someoneElsesTaskIsRefused() {
    Test.setMock(
      HttpCalloutMock.class,
      SalesReportTestFactory.taskFileMock(
        '005000000000001AAA',
        Datetime.now(),
        0
      )
    );

    Test.startTest();
    SalesReportException e = attachExpectingFailure(
      TASK_ID,
      'a.jpg',
      Blob.valueOf('x')
    );
    Test.stopTest();

    Assert.areEqual(SalesReportException.NOT_AUTHORIZED, e.code, 'Code');
    Assert.areEqual(403, e.statusCode, 'Status');
  }

  @IsTest
  static void oldTaskIsRefused() {
    Test.setMock(
      HttpCalloutMock.class,
      SalesReportTestFactory.taskFileMock(
        UserInfo.getUserId(),
        Datetime.now()
          .addMinutes(
            -SalesReportActivityFileService.ATTACH_WINDOW_MINUTES - 5
          ),
        0
      )
    );

    Test.startTest();
    SalesReportException e = attachExpectingFailure(
      TASK_ID,
      'a.jpg',
      Blob.valueOf('x')
    );
    Test.stopTest();

    Assert.areEqual(SalesReportException.INVALID_INPUT, e.code, 'Code');
  }

  @IsTest
  static void fileCountLimitIsKept() {
    Test.setMock(
      HttpCalloutMock.class,
      SalesReportTestFactory.taskFileMock(
        UserInfo.getUserId(),
        Datetime.now(),
        SalesReportSettingsService.attachmentMaxFiles()
      )
    );

    Test.startTest();
    SalesReportException e = attachExpectingFailure(
      TASK_ID,
      'a.jpg',
      Blob.valueOf('x')
    );
    Test.stopTest();

    Assert.isTrue(e.getMessage().contains('up to'), 'Count message');
  }

  @IsTest
  static void inputIsCheckedBeforeAnyCallout() {
    insert new SalesReport_Settings__c(
      SetupOwnerId = UserInfo.getOrganizationId(),
      Attachment_Max_Size_Mb__c = 1
    );
    SalesReportHttpMock http = SalesReportTestFactory.taskFileMock(
      UserInfo.getUserId(),
      Datetime.now(),
      0
    );
    Test.setMock(HttpCalloutMock.class, http);
    Blob tooLarge = Blob.valueOf('x'.repeat(1024 * 1024 + 1));

    Map<String, List<Object>> cases = new Map<String, List<Object>>{
      'bad task id' => new List<Object>{
        '001000000000001AAA',
        'a.jpg',
        Blob.valueOf('x')
      },
      'no extension' => new List<Object>{ TASK_ID, 'photo', Blob.valueOf('x') },
      'wrong type' => new List<Object>{ TASK_ID, 'run.exe', Blob.valueOf('x') },
      'empty' => new List<Object>{ TASK_ID, 'a.jpg', Blob.valueOf('') },
      'too large' => new List<Object>{ TASK_ID, 'a.pdf', tooLarge }
    };
    for (String label : cases.keySet()) {
      List<Object> args = cases.get(label);
      SalesReportException e = attachExpectingFailure(
        (String) args[0],
        (String) args[1],
        (Blob) args[2]
      );
      Assert.areEqual(SalesReportException.INVALID_INPUT, e.code, label);
    }
    Assert.isTrue(http.requests.isEmpty(), 'Nothing sent to Salesforce');
  }

  @IsTest
  static void fileNamesAreCleaned() {
    Assert.areEqual(
      'IMG 1.JPG',
      SalesReportActivityFileService.cleanName('C:\\fakepath/IMG \u0007 1.JPG'),
      'Path, control characters and spaces'
    );
    String longName = 'x'.repeat(300) + '.pdf';
    String cleaned = SalesReportActivityFileService.cleanName(longName);
    Assert.areEqual(
      SalesReportActivityFileService.MAX_NAME_LENGTH,
      cleaned.length(),
      'Shortened'
    );
    Assert.isTrue(cleaned.endsWith('.pdf'), 'Extension kept');
  }
}
