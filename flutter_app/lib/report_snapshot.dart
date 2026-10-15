/// The report context travels with each serverless request. Original PDF bytes
/// and the large viewer text layer stay in the browser.
Map<String, dynamic> reportSnapshot(Map<String, dynamic> report) => {
      for (final key in [
        'report_id',
        'parsed_data',
        'extraction_version',
        'extracted_text',
        'extraction_quality',
        'input_type',
        'report_date',
        'review',
        'target_language'
      ])
        if (report.containsKey(key)) key: report[key],
    };
