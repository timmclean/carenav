window.server = do ->
	sendGet = (url, callback) ->
		sendRequest('GET', url, null, callback)

	sendPost = (url, body, callback) ->
		sendRequest('POST', url, body, callback)

	sendRequest = (method, url, body, callback) ->
		netReq = new XMLHttpRequest()
		netReq.open(method, url, true)
		netReq.onreadystatechange = ->
			if netReq.readyState is 4
				callback(JSON.parse(netReq.responseText))
		if body
			netReq.setRequestHeader('Content-Type', 'application/json')
		netReq.send((body && JSON.stringify(body)) || null)

	return {
		getPatientInfo: (callback) ->
			sendGet '/api/get-patient-info/1', (response) ->
				callback response

		createPatientSurvey: (templateId, callback) ->
			sendPost '/api/create-patient-survey', {templateId}, (response) ->
				callback response

		getIncompletePatientSurveys: (callback) ->
			sendGet '/api/get-incomplete-patient-surveys', (response) ->
				callback response

		getSurveyTemplate: (surveyTemplateId, callback) ->
			sendGet "/api/get-survey-template/#{surveyTemplateId}", (surveyTemplate) ->
				callback surveyTemplate

		submitSurveyData: (surveyId, surveyData, callback) ->
			sendPost '/api/submit-survey-data', {surveyId, surveyData}, callback

		getCompletePatientSurveys: (callback) ->
			sendGet '/api/get-complete-patient-surveys/1', callback

		getNextUpdate: (callback) ->
			sendPost '/api/get-next-update', null, callback
	}

