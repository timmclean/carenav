window.templates = {
	get: _.memoize (name) ->
		return _.template($(".#{name}.template").html())

	render: (name, data) ->
		return this.get(name)(data)
}

$ ->
	findById = (objId, objs) ->
		return _.find objs, (obj) ->
			return obj.id is objId

	_.templateSettings.variable = 'obj'

	showMainScreen = (elem) ->
		$(elem).html(templates.render('main'))
		$(elem).addClass('loading')

		server.getPatientInfo (patientInfo) ->
			$(elem).find('.patientInfo').html(templates.render('patientInfo', patientInfo))
			$(elem).removeClass('loading')

			updateLoop(elem, patientInfo)

	updateLoop = (elem, patientInfo) ->
		showSurveys(elem, patientInfo)

		server.getNextUpdate ->
			updateLoop(elem, patientInfo)

	renderId = -1

	showSurveys = (elem, patientInfo) ->
		myRenderId = Math.random()
		renderId = myRenderId

		server.getIncompletePatientSurveys (surveys) ->
			$(elem).find('.surveys').html(
				(templates.render('surveyListItem', survey) for survey in surveys).join('')
			)

			$(elem).find('.surveys').on 'click', '.survey .link > a', (event) ->
				if renderId isnt myRenderId
					return

				event.preventDefault()

				surveyElem = $(event.target).parents('.survey')
				surveyId = surveyElem.data('id')
				survey = findById(surveyId, surveys)

				$('.survey.modal').html(templates.render('surveyModal', survey))
				$('.survey.modal').modal('show')
				$('.survey.modal .submit.btn').click (event) ->
					event.preventDefault()

					$(this).button('loading')

					# Collect form inputs
					formData = {}
					$('.survey.modal form input').each ->
						if this.name
							formData[this.name] = $(this).val()

					server.submitSurveyData surveyId, formData, (response) ->
						if response.status is 'ok'
							$('.survey.modal').modal('hide')
							surveyElem.addClass('completed')
						else
							alert("Error submitting survey: #{response.status}")

	showMainScreen($('body > .wrapper').get(0))

