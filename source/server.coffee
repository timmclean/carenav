#!/usr/bin/env node

_ = require('underscore')
crypto = require('crypto')
express = require('express')
mongo = require('mongojs')

db = mongo.connect 'icare', [
	'patientInfo',
	'survey',
	'surveyTemplate',
]

app = express()

app.use('/', express.static('client/index.html'))
app.use('/', express.static('client'))

generateId = (cb) ->
	crypto.randomBytes 96, (err, buf) ->
		cb buf.toString('base64').replace(/\//g, '_').replace(/\+/g, '-') # URL-safe

patientId = '1'
updateListeners = []

publishUpdate = ->
	for l in updateListeners
		l()

	updateListeners = []

sendResponse = (res, obj) ->
	res.set('Cache-Control', 'no-cache')
	res.set('Content-Type', 'application/json')
	res.send(JSON.stringify(obj))

app.param 'id', (req, res, next, id) ->
	unless /^[0-9a-zA-Z-_ ]+$/.exec(id)
		next(new Error('Invalid ID'))

	req.id = id
	next()

app.get '/api/get-patient-info/:id', (req, res) ->
	db.patientInfo.find {id: req.id}, (err, results) ->
		sendResponse(res, results[0])

app.get '/api/get-survey-template/:id', (req, res) ->
	db.surveyTemplate.find {id: req.id}, (err, results) ->
		sendResponse(res, results[0])

app.get '/api/get-incomplete-patient-surveys', (req, res) ->
	db.survey.find {isComplete: false}, (err, results) ->
		sendResponse(res, results)

app.post '/api/create-patient-survey', express.bodyParser(), (req, res) ->
	generateId (id) ->
		db.surveyTemplate.find {id: req.body.templateId}, (err, results) ->
			template = results[0]
			survey = {
				id
				isComplete: false
				templateId: req.body.templateId
				name: template.name
				htmlTemplate: template.htmlTemplate
				patientId
			}
			db.survey.insert survey, (err) ->
				if err
					sendResponse(res, {status: 'fail'})
				else
					sendResponse(res, {status: 'ok'})
					publishUpdate()

app.post '/api/submit-survey-data', express.bodyParser(), (req, res) ->
	db.survey.find {id: req.body.surveyId}, (err, results) ->
		survey = results[0]
		survey.isComplete = true
		survey.results = req.body.surveyData

		db.survey.update {id: survey.id}, survey, (err) ->
			if err
				sendResponse(res, {status: 'fail'})
			else
				sendResponse(res, {status: 'ok'})
				publishUpdate()

app.get '/api/get-complete-patient-surveys/:id', (req, res) ->
	db.survey.find {patientId: req.id, isComplete: true}, (err, results) ->
		sendResponse(res, results)

app.post '/api/get-next-update', (req, res) ->
	updateListeners.push ->
		sendResponse(res, {})

app.listen(9001)

db.surveyTemplate.remove {}, (err) ->
	db.surveyTemplate.insert {
		id: '1'
		name: 'ESAS'
		htmlTemplate: '''
			<style scoped>
				.slider-group {
					margin-bottom: 10px;
				}

				.slider-group > span:first-child {
					display: inline-block;
					width: 180px;
					text-align: right;
				}

				.completed-by {
					display: block;
				}
			</style>
			<div class="slider-group">
				<span class="add-on">No Pain</span>
				<input name="pain" type="range" width="20%" min="0" max="10" step="1" value="<%- obj.results && obj.results.pain || '' %>" />
				<span class="after add-on">Lots of Pain</span>
			</div>
			<div class="slider-group">
				<span class="add-on">No Tiredness</span>
				<input name="tiredness" type="range" width="20%" min="0" max="10" step="1" value="<%- obj.results && obj.results.tiredness || '' %>" />
				<span class="add-on">Always Tired</span>
			</div>
			<div class="slider-group">
				<span class="add-on">Not Nauseated</span>
				<input name="nausea" type="range" width="20%" min="0" max="10" step="1" value="<%- obj.results && obj.results.nausea || '' %>" />
				<span class="add-on">Worst Possible Nausea</span>
			</div>
			<div class="slider-group">
				<span class="add-on">No Depression</span>
				<input name="depression" type="range" width="20%" min="0" max="10" step="1" value="<%- obj.results && obj.results.depression || '' %>" />
				<span class="add-on">Worst Possible Depression</span>
			</div>
			<div class="slider-group">
				<span class="add-on">No Anxiety</span>
				<input name="anxiety" type="range" width="20%" min="0" max="10" step="1" value="<%- obj.results && obj.results.anxiety || '' %>" />
				<span class="add-on">Worst Possible Anxiety</span>
			</div>
			<div class="slider-group">
				<span class="add-on">No Drowsiness</span>
				<input name="drowsiness" type="range" width="20%" min="0" max="10" step="1" value="<%- obj.results && obj.results.drowsiness || '' %>" />
				<span class="add-on">Always Drowsy</span>
			</div>
			<div class="slider-group">
				<span class="add-on">Good Appetite</span>
				<input name="appetite" type="range" width="20%" min="0" max="10" step="1" value="<%- obj.results && obj.results.appetite || '' %>" />
				<span class="add-on">No Appetite</span>
			</div>
			<div class="slider-group">
				<span class="add-on">Best Feeling of Wellbeing</span>
				<input name="wellbeing" type="range" width="20%" min="0" max="10" step="1" value="<%- obj.results && obj.results.wellbeing || '' %>" />
				<span class="add-on">Worst Possible Feeling of Wellbeing</span>
			</div>
			<div class="slider-group">
				<span class="add-on">No Shortness of Breath</span>
				<input name="shortnessOfBreath" type="range" width="20%" min="0" max="10" step="1" value="<%- obj.results && obj.results.shortnessOfBreath || '' %>" />
				<span class="add-on">Worst Possible Shortness of Breath</span>
			</div>
			<div class="slider-group">
				<span class="add-on">Other Problem</span>
				<input name="other" type="range" width="20%" min="0" max="10" step="1" value="<%- obj.results && obj.results.other || '' %>" />
				<input type="text" placeholder="Please Indicate" />
			</div>
			<div class="completed-by">
				<span>Completed By: </span>
				<label class="radio inline">
					<input type="radio" name="optionsRadios" id="optionsRadios1" value="option1" checked>
					Patient
				</label>
				<label class="radio inline">
					<input type="radio" name="optionsRadios" id="optionsRadios2" value="option2">
					Caregiver
				</label>
				<label class="radio inline">
					<input type="radio" name="optionsRadios" id="optionsRadios3" value="option3">
					Caregiver - assisted
				</label>
			</div>'''
	}

	db.surveyTemplate.insert {
		id: '2'
		name: 'Toxicity'
		htmlTemplate: '''
			<style>
				.btn-group {
					display: inline-block;

				}
				.itemTitle {
					width: 200px;
					display: inline-block;
				}
			</style>
			<script>
				$(function() {
					$(".btn").click(function(event) {
						event.preventDefault();
						$(this).parent().parent().find("input[type=hidden]").val($(this).text());
					});
				})
			</script>
			<div class="location-group">
				<h4>1. Digestive</h4>
				<div>
					<span class="itemTitle" >a. Nausea and/or vomiting</span>
					<div class="btn-group" data-toggle="buttons-radio">
						<button class="btn active">0</button>
						<button class="btn">1</button>
						<button class="btn">2</button>
						<button class="btn">3</button>
						<button class="btn">4</button>
					</div>
					<input type="hidden" name="1a" />
				</div>
				<div>
					<span class="itemTitle" >b. Diarrhea</span>
					<div class="btn-group" data-toggle="buttons-radio">
						<button class="btn active">0</button>
						<button class="btn">1</button>
						<button class="btn">2</button>
						<button class="btn">3</button>
						<button class="btn">4</button>
					</div>
					<input type="hidden" name="1b" />
				</div>
				<div>
					<span class="itemTitle" >c. Constipation</span>
					<div class="btn-group" data-toggle="buttons-radio">
						<button class="btn active">0</button>
						<button class="btn">1</button>
						<button class="btn">2</button>
						<button class="btn">3</button>
						<button class="btn">4</button>
					</div>
					<input type="hidden" name="1c" />
				</div>
				<div>
					<span class="itemTitle" >d. Bloated feeling</span>
					<div class="btn-group" data-toggle="buttons-radio">
						<button class="btn active">0</button>
						<button class="btn">1</button>
						<button class="btn">2</button>
						<button class="btn">3</button>
						<button class="btn">4</button>
					</div>
					<input type="hidden" name="1d" />
				</div>
				<div>
					<span class="itemTitle" >e. Belching and/or pasing gas</span>
					<div class="btn-group" data-toggle="buttons-radio">
						<button class="btn active">0</button>
						<button class="btn">1</button>
						<button class="btn">2</button>
						<button class="btn">3</button>
						<button class="btn">4</button>
					</div>
					<input type="hidden" name="1e" />
				</div>
				<div>
					<span class="itemTitle" >f. Heartburn</span>
					<div class="btn-group" data-toggle="buttons-radio">
						<button class="btn active">0</button>
						<button class="btn">1</button>
						<button class="btn">2</button>
						<button class="btn">3</button>
						<button class="btn">4</button>
					</div>
					<input type="hidden" name="1f" />
				</div>
			</div>
			<div class="location-group">
				<h4>2. Ears</h4>
				<div>
					<span class="itemTitle" >a. Itchy ears</span>
					<div class="btn-group" data-toggle="buttons-radio">
						<button class="btn active">0</button>
						<button class="btn">1</button>
						<button class="btn">2</button>
						<button class="btn">3</button>
						<button class="btn">4</button>
					</div>
					<input type="hidden" name="2a" />
				</div>
				<div>
					<span class="itemTitle" >b. Earaches or ear infections</span>
					<div class="btn-group" data-toggle="buttons-radio">
						<button class="btn active">0</button>
						<button class="btn">1</button>
						<button class="btn">2</button>
						<button class="btn">3</button>
						<button class="btn">4</button>
					</div>
					<input type="hidden" name="2b" />
				</div>
				<div>
					<span class="itemTitle" >c. Draining from ear</span>
					<div class="btn-group" data-toggle="buttons-radio">
						<button class="btn active">0</button>
						<button class="btn">1</button>
						<button class="btn">2</button>
						<button class="btn">3</button>
						<button class="btn">4</button>
					</div>
					<input type="hidden" name="2c" />
				</div>
				<div>
					<span class="itemTitle" >d. Ringing in ears or hearing loss</span>
					<div class="btn-group" data-toggle="buttons-radio">
						<button class="btn active">0</button>
						<button class="btn">1</button>
						<button class="btn">2</button>
						<button class="btn">3</button>
						<button class="btn">4</button>
					</div>
					<input type="hidden" name="2d" />
				</div>
			</div>
			<div class="location-group">
				<h4>3. Emotions</h4>
				<div>
					<span class="itemTitle" >a. Mood swings</span>
					<div class="btn-group" data-toggle="buttons-radio">
						<button class="btn active">0</button>
						<button class="btn">1</button>
						<button class="btn">2</button>
						<button class="btn">3</button>
						<button class="btn">4</button>
					</div>
					<input type="hidden" name="3a" />
				</div>
				<div>
					<span class="itemTitle" >b. Anxiety, fear, or nervousness</span>
					<div class="btn-group" data-toggle="buttons-radio">
						<button class="btn active">0</button>
						<button class="btn">1</button>
						<button class="btn">2</button>
						<button class="btn">3</button>
						<button class="btn">4</button>
					</div>
					<input type="hidden" name="3b" />
				</div>
				<div>
					<span class="itemTitle" >c. Anger, irritability</span>
					<div class="btn-group" data-toggle="buttons-radio">
						<button class="btn active">0</button>
						<button class="btn">1</button>
						<button class="btn">2</button>
						<button class="btn">3</button>
						<button class="btn">4</button>
					</div>
					<input type="hidden" name="3c" />
				</div>
				<div>
					<span class="itemTitle" >d. Depression</span>
					<div class="btn-group" data-toggle="buttons-radio">
						<button class="btn active">0</button>
						<button class="btn">1</button>
						<button class="btn">2</button>
						<button class="btn">3</button>
						<button class="btn">4</button>
					</div>
					<input type="hidden" name="3d" />
				</div>
				<div>
					<span class="itemTitle" >e. Sense of despair</span>
					<div class="btn-group" data-toggle="buttons-radio">
						<button class="btn active">0</button>
						<button class="btn">1</button>
						<button class="btn">2</button>
						<button class="btn">3</button>
						<button class="btn">4</button>
					</div>
					<input type="hidden" name="3e" />
				</div>
				<div>
					<span class="itemTitle" >f. Uncaring or disinterested</span>
					<div class="btn-group" data-toggle="buttons-radio">
						<button class="btn active">0</button>
						<button class="btn">1</button>
						<button class="btn">2</button>
						<button class="btn">3</button>
						<button class="btn">4</button>
					</div>
					<input type="hidden" name="3f" />
				</div>
			</div>
			<div class="location-group">
				<h4>4. Energy/Activity</h4>
				<div>
					<span class="itemTitle" >a. Fatigue or sluggishness</span>
					<div class="btn-group" data-toggle="buttons-radio">
						<button class="btn active">0</button>
						<button class="btn">1</button>
						<button class="btn">2</button>
						<button class="btn">3</button>
						<button class="btn">4</button>
					</div>
					<input type="hidden" name="4a" />
				</div>
				<div>
					<span class="itemTitle" >b. Hyperactivity</span>
					<div class="btn-group" data-toggle="buttons-radio">
						<button class="btn active">0</button>
						<button class="btn">1</button>
						<button class="btn">2</button>
						<button class="btn">3</button>
						<button class="btn">4</button>
					</div>
					<input type="hidden" name="4b" />
				</div>
				<div>
					<span class="itemTitle" >c. Restlessness</span>
					<div class="btn-group" data-toggle="buttons-radio">
						<button class="btn active">0</button>
						<button class="btn">1</button>
						<button class="btn">2</button>
						<button class="btn">3</button>
						<button class="btn">4</button>
					</div>
					<input type="hidden" name="4c" />
				</div>
				<div>
					<span class="itemTitle" >d. Insomnia</span>
					<div class="btn-group" data-toggle="buttons-radio">
						<button class="btn active">0</button>
						<button class="btn">1</button>
						<button class="btn">2</button>
						<button class="btn">3</button>
						<button class="btn">4</button>
					</div>
					<input type="hidden" name="4d" />
				</div>
				<div>
					<span class="itemTitle" >e. Startled awake at night</span>
					<div class="btn-group" data-toggle="buttons-radio">
						<button class="btn active">0</button>
						<button class="btn">1</button>
						<button class="btn">2</button>
						<button class="btn">3</button>
						<button class="btn">4</button>
					</div>
					<input type="hidden" name="4e" />
				</div>
			</div>
			<div class="location-group">
				<h4>5. Eyes</h4>
				<div>
					<span class="itemTitle" >a. Watery or itchy eyes</span>
					<div class="btn-group" data-toggle="buttons-radio">
						<button class="btn active">0</button>
						<button class="btn">1</button>
						<button class="btn">2</button>
						<button class="btn">3</button>
						<button class="btn">4</button>
					</div>
					<input type="hidden" name="5a" />
				</div>
				<div>
					<span class="itemTitle" >b. Swollen, reddened, or stiky eyelids</span>
					<div class="btn-group" data-toggle="buttons-radio">
						<button class="btn active">0</button>
						<button class="btn">1</button>
						<button class="btn">2</button>
						<button class="btn">3</button>
						<button class="btn">4</button>
					</div>
					<input type="hidden" name="5b" />
				</div>
				<div>
					<span class="itemTitle" >c. Dark circles under eyes</span>
					<div class="btn-group" data-toggle="buttons-radio">
						<button class="btn active">0</button>
						<button class="btn">1</button>
						<button class="btn">2</button>
						<button class="btn">3</button>
						<button class="btn">4</button>
					</div>
					<input type="hidden" name="5c" />
				</div>
				<div>
					<span class="itemTitle" >d. Blurred or tunnel vision</span>
					<div class="btn-group" data-toggle="buttons-radio">
						<button class="btn active">0</button>
						<button class="btn">1</button>
						<button class="btn">2</button>
						<button class="btn">3</button>
						<button class="btn">4</button>
					</div>
					<input type="hidden" name="5d" />
				</div>
			</div>
			<div class="location-group">
				<h4>6. Head</h4>
				<div>
					<span class="itemTitle" >a. Headaches</span>
					<div class="btn-group" data-toggle="buttons-radio">
						<button class="btn active">0</button>
						<button class="btn">1</button>
						<button class="btn">2</button>
						<button class="btn">3</button>
						<button class="btn">4</button>
					</div>
					<input type="hidden" name="6a" />
				</div>
				<div>
					<span class="itemTitle" >b. Faintness</span>
					<div class="btn-group" data-toggle="buttons-radio">
						<button class="btn active">0</button>
						<button class="btn">1</button>
						<button class="btn">2</button>
						<button class="btn">3</button>
						<button class="btn">4</button>
					</div>
					<input type="hidden" name="6b" />
				</div>
				<div>
					<span class="itemTitle" >c. Dizziness</span>
					<div class="btn-group" data-toggle="buttons-radio">
						<button class="btn active">0</button>
						<button class="btn">1</button>
						<button class="btn">2</button>
						<button class="btn">3</button>
						<button class="btn">4</button>
					</div>
					<input type="hidden" name="6c" />
				</div>
				<div>
					<span class="itemTitle" >d. Pressure</span>
					<div class="btn-group" data-toggle="buttons-radio">
						<button class="btn active">0</button>
						<button class="btn">1</button>
						<button class="btn">2</button>
						<button class="btn">3</button>
						<button class="btn">4</button>
					</div>
					<input type="hidden" name="6d" />
				</div>
			</div>
			<div class="location-group">
				<h4>7. Lungs</h4>
				<div>
					<span class="itemTitle" >a. Chest congestion</span>
					<div class="btn-group" data-toggle="buttons-radio">
						<button class="btn active">0</button>
						<button class="btn">1</button>
						<button class="btn">2</button>
						<button class="btn">3</button>
						<button class="btn">4</button>
					</div>
					<input type="hidden" name="7a" />
				</div>
				<div>
					<span class="itemTitle" >b. Asthma or bronchitis</span>
					<div class="btn-group" data-toggle="buttons-radio">
						<button class="btn active">0</button>
						<button class="btn">1</button>
						<button class="btn">2</button>
						<button class="btn">3</button>
						<button class="btn">4</button>
					</div>
					<input type="hidden" name="7b" />
				</div>
				<div>
					<span class="itemTitle" >c. Shortness of breath</span>
					<div class="btn-group" data-toggle="buttons-radio">
						<button class="btn active">0</button>
						<button class="btn">1</button>
						<button class="btn">2</button>
						<button class="btn">3</button>
						<button class="btn">4</button>
					</div>
					<input type="hidden" name="7c" />
				</div>
				<div>
					<span class="itemTitle" >d. Difficulty breathing</span>
					<div class="btn-group" data-toggle="buttons-radio">
						<button class="btn active">0</button>
						<button class="btn">1</button>
						<button class="btn">2</button>
						<button class="btn">3</button>
						<button class="btn">4</button>
					</div>
					<input type="hidden" name="7d" />
				</div>
			</div>
			<div class="location-group">
				<h4>8. Mind</h4>
				<div>
					<span class="itemTitle" >a. Poor memory</span>
					<div class="btn-group" data-toggle="buttons-radio">
						<button class="btn active">0</button>
						<button class="btn">1</button>
						<button class="btn">2</button>
						<button class="btn">3</button>
						<button class="btn">4</button>
					</div>
					<input type="hidden" name="8a" />
				</div>
				<div>
					<span class="itemTitle" >b. Confusion</span>
					<div class="btn-group" data-toggle="buttons-radio">
						<button class="btn active">0</button>
						<button class="btn">1</button>
						<button class="btn">2</button>
						<button class="btn">3</button>
						<button class="btn">4</button>
					</div>
					<input type="hidden" name="8b" />
				</div>
				<div>
					<span class="itemTitle" >c. Poor concentration</span>
					<div class="btn-group" data-toggle="buttons-radio">
						<button class="btn active">0</button>
						<button class="btn">1</button>
						<button class="btn">2</button>
						<button class="btn">3</button>
						<button class="btn">4</button>
					</div>
					<input type="hidden" name="8c" />
				</div>
				<div>
					<span class="itemTitle" >d. Poor coordination</span>
					<div class="btn-group" data-toggle="buttons-radio">
						<button class="btn active">0</button>
						<button class="btn">1</button>
						<button class="btn">2</button>
						<button class="btn">3</button>
						<button class="btn">4</button>
					</div>
					<input type="hidden" name="8d" />
				</div>
				<div>
					<span class="itemTitle" >e. Difficulty making decisions</span>
					<div class="btn-group" data-toggle="buttons-radio">
						<button class="btn active">0</button>
						<button class="btn">1</button>
						<button class="btn">2</button>
						<button class="btn">3</button>
						<button class="btn">4</button>
					</div>
					<input type="hidden" name="8e" />
				</div>
				<div>
					<span class="itemTitle" >f. Stuttering, stammering</span>
					<div class="btn-group" data-toggle="buttons-radio">
						<button class="btn active">0</button>
						<button class="btn">1</button>
						<button class="btn">2</button>
						<button class="btn">3</button>
						<button class="btn">4</button>
					</div>
					<input type="hidden" name="8f" />
				</div>
				<div>
					<span class="itemTitle" >g. Slurred speech</span>
					<div class="btn-group" data-toggle="buttons-radio">
						<button class="btn active">0</button>
						<button class="btn">1</button>
						<button class="btn">2</button>
						<button class="btn">3</button>
						<button class="btn">4</button>
					</div>
					<input type="hidden" name="8g" />
				</div>
				<div>
					<span class="itemTitle" >h. Learning disabilities</span>
					<div class="btn-group" data-toggle="buttons-radio">
						<button class="btn active">0</button>
						<button class="btn">1</button>
						<button class="btn">2</button>
						<button class="btn">3</button>
						<button class="btn">4</button>
					</div>
					<input type="hidden" name="8h" />
				</div>
			</div>
			<div class="location-group">
				<h4>9. Mouth/Throat</h4>
				<div>
					<span class="itemTitle" >a. Chronic coughing</span>
					<div class="btn-group" data-toggle="buttons-radio">
						<button class="btn active">0</button>
						<button class="btn">1</button>
						<button class="btn">2</button>
						<button class="btn">3</button>
						<button class="btn">4</button>
					</div>
					<input type="hidden" name="9a" />
				</div>
				<div>
					<span class="itemTitle" >b. Gagging or frequent need to clear throat</span>
					<div class="btn-group" data-toggle="buttons-radio">
						<button class="btn active">0</button>
						<button class="btn">1</button>
						<button class="btn">2</button>
						<button class="btn">3</button>
						<button class="btn">4</button>
					</div>
					<input type="hidden" name="9b" />
				</div>
				<div>
					<span class="itemTitle" >c. Swollen or discolored tongue, gums, lips</span>
					<div class="btn-group" data-toggle="buttons-radio">
						<button class="btn active">0</button>
						<button class="btn">1</button>
						<button class="btn">2</button>
						<button class="btn">3</button>
						<button class="btn">4</button>
					</div>
					<input type="hidden" name="9c" />
				</div>
				<div>
					<span class="itemTitle" >d. Canker sores</span>
					<div class="btn-group" data-toggle="buttons-radio">
						<button class="btn active">0</button>
						<button class="btn">1</button>
						<button class="btn">2</button>
						<button class="btn">3</button>
						<button class="btn">4</button>
					</div>
					<input type="hidden" name="9d" />
				</div>
			</div>
			<div class="location-group">
				<h4>10. Nose</h4>
				<div>
					<span class="itemTitle" >a. Stuffy nose</span>
					<div class="btn-group" data-toggle="buttons-radio">
						<button class="btn active">0</button>
						<button class="btn">1</button>
						<button class="btn">2</button>
						<button class="btn">3</button>
						<button class="btn">4</button>
					</div>
					<input type="hidden" name="10a" />
				</div>
				<div>
					<span class="itemTitle" >b. Sinus problems</span>
					<div class="btn-group" data-toggle="buttons-radio">
						<button class="btn active">0</button>
						<button class="btn">1</button>
						<button class="btn">2</button>
						<button class="btn">3</button>
						<button class="btn">4</button>
					</div>
					<input type="hidden" name="10b" />
				</div>
				<div>
					<span class="itemTitle" >c. Hay fever</span>
					<div class="btn-group" data-toggle="buttons-radio">
						<button class="btn active">0</button>
						<button class="btn">1</button>
						<button class="btn">2</button>
						<button class="btn">3</button>
						<button class="btn">4</button>
					</div>
					<input type="hidden" name="10c" />
				</div>
				<div>
					<span class="itemTitle" >d. Sneezing attacks</span>
					<div class="btn-group" data-toggle="buttons-radio">
						<button class="btn active">0</button>
						<button class="btn">1</button>
						<button class="btn">2</button>
						<button class="btn">3</button>
						<button class="btn">4</button>
					</div>
					<input type="hidden" name="10d" />
				</div>
				<div>
					<span class="itemTitle" >e. Excessive mucous</span>
					<div class="btn-group" data-toggle="buttons-radio">
						<button class="btn active">0</button>
						<button class="btn">1</button>
						<button class="btn">2</button>
						<button class="btn">3</button>
						<button class="btn">4</button>
					</div>
					<input type="hidden" name="10e" />
				</div>
			</div>
			<div class="location-group">
				<h4>11. Skin</h4>
				<div>
					<span class="itemTitle" >a. Acne</span>
					<div class="btn-group" data-toggle="buttons-radio">
						<button class="btn active">0</button>
						<button class="btn">1</button>
						<button class="btn">2</button>
						<button class="btn">3</button>
						<button class="btn">4</button>
					</div>
					<input type="hidden" name="11a" />
				</div>
				<div>
					<span class="itemTitle" >b. Hives, rashes, or dry skin</span>
					<div class="btn-group" data-toggle="buttons-radio">
						<button class="btn active">0</button>
						<button class="btn">1</button>
						<button class="btn">2</button>
						<button class="btn">3</button>
						<button class="btn">4</button>
					</div>
					<input type="hidden" name="11b" />
				</div>
				<div>
					<span class="itemTitle" >c. Hair loss</span>
					<div class="btn-group" data-toggle="buttons-radio">
						<button class="btn active">0</button>
						<button class="btn">1</button>
						<button class="btn">2</button>
						<button class="btn">3</button>
						<button class="btn">4</button>
					</div>
					<input type="hidden" name="11c" />
				</div>
				<div>
					<span class="itemTitle" >d. Flushing</span>
					<div class="btn-group" data-toggle="buttons-radio">
						<button class="btn active">0</button>
						<button class="btn">1</button>
						<button class="btn">2</button>
						<button class="btn">3</button>
						<button class="btn">4</button>
					</div>
					<input type="hidden" name="11d" />
				</div>
				<div>
					<span class="itemTitle" >e. Excessive sweating</span>
					<div class="btn-group" data-toggle="buttons-radio">
						<button class="btn active">0</button>
						<button class="btn">1</button>
						<button class="btn">2</button>
						<button class="btn">3</button>
						<button class="btn">4</button>
					</div>
					<input type="hidden" name="11e" />
				</div>
			</div>
			<div class="location-group">
				<h4>12. Heart</h4>
				<div>
					<span class="itemTitle" >a. Skipped heartbeats</span>
					<div class="btn-group" data-toggle="buttons-radio">
						<button class="btn active">0</button>
						<button class="btn">1</button>
						<button class="btn">2</button>
						<button class="btn">3</button>
						<button class="btn">4</button>
					</div>
					<input type="hidden" name="12a" />
				</div>
				<div>
					<span class="itemTitle" >b. Rapid heartbeats</span>
					<div class="btn-group" data-toggle="buttons-radio">
						<button class="btn active">0</button>
						<button class="btn">1</button>
						<button class="btn">2</button>
						<button class="btn">3</button>
						<button class="btn">4</button>
					</div>
					<input type="hidden" name="12b" />
				</div>
				<div>
					<span class="itemTitle" >c. Chest pain</span>
					<div class="btn-group" data-toggle="buttons-radio">
						<button class="btn active">0</button>
						<button class="btn">1</button>
						<button class="btn">2</button>
						<button class="btn">3</button>
						<button class="btn">4</button>
					</div>
					<input type="hidden" name="12c" />
				</div>
			</div>
			<div class="location-group">
				<h4>13. Joints/Muscles</h4>
				<div>
					<span class="itemTitle" >a. Pain or aches in joints</span>
					<div class="btn-group" data-toggle="buttons-radio">
						<button class="btn active">0</button>
						<button class="btn">1</button>
						<button class="btn">2</button>
						<button class="btn">3</button>
						<button class="btn">4</button>
					</div>
					<input type="hidden" name="13a" />
				</div>
				<div>
					<span class="itemTitle" >b. Rheumatoid arthritis</span>
					<div class="btn-group" data-toggle="buttons-radio">
						<button class="btn active">0</button>
						<button class="btn">1</button>
						<button class="btn">2</button>
						<button class="btn">3</button>
						<button class="btn">4</button>
					</div>
					<input type="hidden" name="13b" />
				</div>
				<div>
					<span class="itemTitle" >c. Osteoarthritis</span>
					<div class="btn-group" data-toggle="buttons-radio">
						<button class="btn active">0</button>
						<button class="btn">1</button>
						<button class="btn">2</button>
						<button class="btn">3</button>
						<button class="btn">4</button>
					</div>
					<input type="hidden" name="13c" />
				</div>
				<div>
					<span class="itemTitle" >d. Stiffness or limited movement</span>
					<div class="btn-group" data-toggle="buttons-radio">
						<button class="btn active">0</button>
						<button class="btn">1</button>
						<button class="btn">2</button>
						<button class="btn">3</button>
						<button class="btn">4</button>
					</div>
					<input type="hidden" name="13d" />
				</div>
				<div>
					<span class="itemTitle" >e. Pain or aches in muscles</span>
					<div class="btn-group" data-toggle="buttons-radio">
						<button class="btn active">0</button>
						<button class="btn">1</button>
						<button class="btn">2</button>
						<button class="btn">3</button>
						<button class="btn">4</button>
					</div>
					<input type="hidden" name="13e" />
				</div>
				<div>
					<span class="itemTitle" >f. Recurrent back aches</span>
					<div class="btn-group" data-toggle="buttons-radio">
						<button class="btn active">0</button>
						<button class="btn">1</button>
						<button class="btn">2</button>
						<button class="btn">3</button>
						<button class="btn">4</button>
					</div>
					<input type="hidden" name="13f" />
				</div>
				<div>
					<span class="itemTitle" >g. Feeling of weakness or tiredness</span>
					<div class="btn-group" data-toggle="buttons-radio">
						<button class="btn active">0</button>
						<button class="btn">1</button>
						<button class="btn">2</button>
						<button class="btn">3</button>
						<button class="btn">4</button>
					</div>
					<input type="hidden" name="13g" />
				</div>
			</div>
			<div class="location-group">
				<h4>14. Weight</h4>
				<div>
					<span class="itemTitle" >a. Binge eating or drinking</span>
					<div class="btn-group" data-toggle="buttons-radio">
						<button class="btn active">0</button>
						<button class="btn">1</button>
						<button class="btn">2</button>
						<button class="btn">3</button>
						<button class="btn">4</button>
					</div>
					<input type="hidden" name="14a" />
				</div>
				<div>
					<span class="itemTitle" >b. Craving certain foods</span>
					<div class="btn-group" data-toggle="buttons-radio">
						<button class="btn active">0</button>
						<button class="btn">1</button>
						<button class="btn">2</button>
						<button class="btn">3</button>
						<button class="btn">4</button>
					</div>
					<input type="hidden" name="14b" />
				</div>
				<div>
					<span class="itemTitle" >c. Excessive weight</span>
					<div class="btn-group" data-toggle="buttons-radio">
						<button class="btn active">0</button>
						<button class="btn">1</button>
						<button class="btn">2</button>
						<button class="btn">3</button>
						<button class="btn">4</button>
					</div>
					<input type="hidden" name="14c" />
				</div>
				<div>
					<span class="itemTitle" >d. Compulsive eating</span>
					<div class="btn-group" data-toggle="buttons-radio">
						<button class="btn active">0</button>
						<button class="btn">1</button>
						<button class="btn">2</button>
						<button class="btn">3</button>
						<button class="btn">4</button>
					</div>
					<input type="hidden" name="14d" />
				</div>
				<div>
					<span class="itemTitle" >e. Water retention</span>
					<div class="btn-group" data-toggle="buttons-radio">
						<button class="btn active">0</button>
						<button class="btn">1</button>
						<button class="btn">2</button>
						<button class="btn">3</button>
						<button class="btn">4</button>
					</div>
					<input type="hidden" name="14e" />
				</div>
				<div>
					<span class="itemTitle" >f. Underweight</span>
					<div class="btn-group" data-toggle="buttons-radio">
						<button class="btn active">0</button>
						<button class="btn">1</button>
						<button class="btn">2</button>
						<button class="btn">3</button>
						<button class="btn">4</button>
					</div>
					<input type="hidden" name="14f" />
				</div>
			</div>
			<div class="location-group">
				<h4>15. Other</h4>
				<div>
					<span class="itemTitle" >a. Frequent illness</span>
					<div class="btn-group" data-toggle="buttons-radio">
						<button class="btn active">0</button>
						<button class="btn">1</button>
						<button class="btn">2</button>
						<button class="btn">3</button>
						<button class="btn">4</button>
					</div>
					<input type="hidden" name="15a" />
				</div>
				<div>
					<span class="itemTitle" >b. Frequent or urgent urination</span>
					<div class="btn-group" data-toggle="buttons-radio">
						<button class="btn active">0</button>
						<button class="btn">1</button>
						<button class="btn">2</button>
						<button class="btn">3</button>
						<button class="btn">4</button>
					</div>
					<input type="hidden" name="15b" />
				</div>
				<div>
					<span class="itemTitle" >c. Leaky bladder</span>
					<div class="btn-group" data-toggle="buttons-radio">
						<button class="btn active">0</button>
						<button class="btn">1</button>
						<button class="btn">2</button>
						<button class="btn">3</button>
						<button class="btn">4</button>
					</div>
					<input type="hidden" name="15c" />
				</div>
				<div>
					<span class="itemTitle" >d. Genital itch, discharge</span>
					<div class="btn-group" data-toggle="buttons-radio">
						<button class="btn active">0</button>
						<button class="btn">1</button>
						<button class="btn">2</button>
						<button class="btn">3</button>
						<button class="btn">4</button>
					</div>
					<input type="hidden" name="15d" />
				</div>
			</div>'''
	}
