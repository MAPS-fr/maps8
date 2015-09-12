/**
 *  SPRITE
 *  Author: Mog
 *  Description: 
 *  SPRITE est un serious game qui a pour vocation de sensibiliser les élus des communes insulaires 
 *  au risque de submersion marine.
 * 
 */

model SPRITE

/* Insert your model definition here */





/***********************************************
 *                   AGENT MONDE               * 
 ***********************************************/

global
{
	// *************************** VARIABLES AGENT MONDE **********************
	//dossier contenant les fichiers à lire
	string dossier_fichiers <-  "../includes/" ;
		
	//chargement du contour de l'ile et du cadre de mer
	file island_shapefile <- file(dossier_fichiers+"contours_ile.shp");
	//geometry lamer <- geometry(first(island_shapefile));
	geometry shape <- envelope(file(dossier_fichiers+"rect.shp"));
		
	//définition des parcelles de mer
	list<parcelle> sea_cells;
	
	//parcelles proches de la mer
   	list<parcelle> merProche;

  	//parcelles non nécessaires pour la submersion
   	list<parcelle> cellulesquiserventarien;
   	
   	//parcelles utilisées pour la submersion
   	list<parcelle> cellulesquiserventaquelquechose;
	
	//liste des parcelles de terre
	list<parcelle> cellulessanseau;
	
	// valeur monétaire de la réparation d'un dommage de 1
	int kopec_dommage <- 50;
	
	// taux de diffusion de l'eau d'une case à une autre
	float diffusion_rate <- 0.6;
	
	//1 paramètre pour dire s'il y a submersion et deux paramètres définissant l'intensité d'une submersion, i.e. la hauteur de celle-ci et sa durée
	//ils sont tirés aléatoirement à chaque tour pour le suspens
	float hauteur_eau;
	int temps_submersion;

	//année (tour de jeu)
	int annee<-2014;
	
		
	//***************** INITIALISATION AGENT MONDE *********************
	init 
	{
	//petit message de lancement
	write "Vous êtes le nouveau président de la communauté urbaine d'Oléron";
	write "A vous de gérer au mieux l'île pour assurer la sécurité et le confort de ses habitants";
	write "tout en sauvegardant la valeur écologique et l'attractivité de l'île";
	write "Il faut aussi que vous pensiez à votre popularité, afin d'être réélu aux prochaines élections";
	write "Vous avez 5 ans (5 tours), de 2015 à 2020 pour faire vos preuves";
	write "Pour commencer la partie, passez au cyle suivant";
		
		//initialisation des parcelles
		do init_cells;
		
		//création des territoires : territoire 0 : mer, territoires 1 à n : communes (pour l'iinstant 1 seule)
		create territoire {
		 id<-0;
		}
		
		create territoire {
		 id<-1;
		}
		
		//affectation des parcelles de mer au territoire 0
		ask parcelle where each.is_sea {
		mon_territoire<-territoire first_with (each.id=0);
		}
		
		//affecation des autres parcelles à la mairie 1 ( à changer si plusieurs communes)
		ask parcelle where !each.is_sea {
		mon_territoire<-territoire first_with (each.id=1);
		}
		
		//remplissage de la liste de parcelle du territoire et du nombre de parcelle (pour moyenne)
		ask territoire where (each.id>0){
		mes_parcelles <-parcelle where (each.mon_territoire.id=id);
		nbparcelle <- length(mes_parcelles);
		}
		
		ask cellulesquiserventarien {already <- true;}
		cellulesquiserventaquelquechose <- parcelle - cellulesquiserventarien;
		
		//coloration initiale des parcelles selon qu'elles soient dans l'eau ou non
		ask (parcelle) {
	 			color <- rgb(int(min([255,max([255 - 20 *altitude, 0])])), 255, int(min([255,max([0,255 - 20 * altitude])])));
		if (is_sea) {
			color <- # blue;
			eau_present<-true;
			}
	 	}
	 	
	ask territoire where (each.id>0) {
		do CalculIndicateur;
	}
	
	}
	//**************************************
	// 				FIN DU INIT
	//************************************
	
	//*************************************************
	//			TOUR DE JEU
	//*************************************************
	
	int phase;
	// Déroulement d'un tour de jeu
	//phase 0 : submersion
	//phase 1 : remise en état de l'île
	//phase 2 : collecte des impots
	//phase 3 : remise à jour des indicateurs
	//phase 4 : actions du joueur
	//phase 5 : test du gameover
	
	reflex nouveauTour {
		phase<-0;
		annee <- annee+1;
		write "****************************************************************";
		write "Nouveau Tour de jeu ; Nous sommes en "+annee;

		ask territoire where (each.id>0){	
			write "Vous disposez d'un budget de "+int(budget)+ " kopecs";	
		}
		do P0;
	}
	
	action P0 {
	write "Phase de submersion";
	do submerger;	
	}
	
	action P1 {
	write "Phase de remise en état de l'île";
	write "Activer la commande Réparation des dommages de la submersion";	
	}
	
	
	action P2 {
		write "Phase de collecte des impôts";
		ask territoire where (each.id>0){
			do recueil_impot;
		}
		phase <-3;
		do P3;
	}	
	
	action P3 {
		//write "Phase de calcul des indicateurs des territoires";
		ask territoire where (each.id>0){
			do CalculIndicateur;
		}
		phase <-4;
		do P4;
	}
	
	action P4 {
		write "Phase d'action des joueurs";
	}
	
	action P5 {
		do gameOver;
	if (annee<2020) {
	write "Vous pouvez passer à l'année suivante (passer au cycle suivant)";
	}
	else {write "fin de la partie, il est temps de regarder le bilan";}
	}
	
	
	//**************ACTION AGENT MONDE********************

	//GAME OVER - condition de perte du jeu
	action gameOver {
		ask territoire {
			if id>0 {
				if avgSecu<1 {write "Le niveau de sécurité sur l'île est trop faible, vous avez perdu !";}
				if avgEcolo<1 {write "Le niveau environnemental de l'île est trop faible, vous avez perdu !";}
				if indicateurPopularite <1 {write "Votre popularitée est trop faible, vous avez perdu !";}
				if dommageMandat >10000 {write "Les dommages causés par les submersions sont trop forts, vous avez perdu !";}
			}	
		}	
	}

	//initialisation des cellules de la grille a partir du csv d'Oléron
	action init_cells
	{
		//passage par un agent cell qui réceptionne les données et les renvoie (surement pas tres optimisé)
		matrix init_data <- matrix(csv_file(dossier_fichiers + "grille_oleron.csv"));
		
		//pop est un incrément récupérant les n° de colonne
		int pop <-1;
		
		//on copie les infos de chaque parcelle à partir de la matrice
		ask parcelle
		{
			altitude<-float(init_data[0,pop]);
			//altitude<-cell[pop].altitude;
			//is_sea<-cell[pop].is_sea;
			is_sea<-bool(init_data[1,pop]);
			
			if (is_sea) {water_height<-(-altitude);}
			digue<-int(init_data[2,pop]);
			densite_bati<-float(init_data[3,pop]);
			if digue>0 {obstacle_height<-float(init_data[4,pop]) #m;}
			neighbour_cells <- (self neighbours_at 1);
			neighbour_cells_far <- (self neighbours_at 2);
			if (densite_bati > 0) {
			maison<-true;}
			else {maison <- false;}
			//remplissage liste de parcelles de mer à coté et la mer est elle a coté
			parcellesVoisinesMer<- neighbour_cells where (each.is_sea);
			if (length(parcellesVoisinesMer))>0 {mer_proche<-true;}
			pop<-pop+1;
		}
		
		sea_cells <- parcelle where each.is_sea;
		cellulessanseau <- parcelle - sea_cells;
		ask parcelle where (!each.is_sea) {do ComputeDistanceSea;}
	}


	//ACTIONS LIES A LA SUBMERSION
	//régénartion de l'eau dans les cellules de mer (pour simuler le remplacement de l'eau)
	action adding_input_water
	{
		float water_input <- rnd(10)/5;
		ask sea_cells {water_height <- water_height + water_input;}
	}

	//mécanisme de submersion  -demande de propagation aux cellules
	action flowing
	{	ask cellulesquiserventaquelquechose
		{
			already <- false;
		}
		ask (cellulesquiserventaquelquechose sort_by ((each.altitude + each.water_height + each.obstacle_height)))
		{
			do flow;
		}
	}
	
	// SUUUBBBBBMMMMEEEERRRRSSSIIIIOOOONNNNNNN
	action submerge {
		hauteur_eau <-	rnd(10)/5 # m;
		ask sea_cells{water_height <- hauteur_eau+altitude;}
		temps_submersion <-5+rnd(10);
	
		//boucle de submersion
		loop i from : 0 to : temps_submersion-3 {
			//flowing
			do adding_input_water;
			do flowing;
			ask parcelle {do releveStatSubm;}
		//condition de fin - a partir de t>tfin, la diffusion diminue
			if i > temps_submersion
			{
				diffusion_rate <- max([0, diffusion_rate - 0.1]);
			}
		}

		ask parcelle{
		color <- rgb(int(min([255,max([255 - 20 *altitude, 0])])), 255, int(min([255,max([0,255 - 20 * altitude])])));
		if (is_sea) {color <- # blue;}
	 	
	 	else if (eau_present=true) {	
				nbSubmersion<-nbSubmersion+1;
				color <-#blue;
				dommage<-densite_bati;
				eau_present<-false;
				}
		 	}	 	
	}
	
// RAZ des parcelles après une submersion
	 action remise_etat_monde {
		ask territoire where (each.id>0){
			do ComputeDommageTotal;
			write "Les dommages ont été réparés pour une somme de "+int(dommageTotal/kopec_dommage)+" kopecs";
			budget <- budget - dommageTotal/kopec_dommage;
			dommageMandat <- int(dommageMandat+dommageTotal);
			dommageTotal<-0.0;
			do affiche_budget;
		}
		ask (parcelle) {
		color <- rgb(int(min([255,max([255 - 20 *altitude, 0])])), 255, int(min([255,max([0,255 - 20 * altitude])])));
		if (is_sea) {color <- # blue;}
	 			dommage<-0.0;
	 	}
	}

	//à utiliser pour finir le tour
	user_command "Fin de Tour" {
		write "L'année "+annee+" est finie";
		phase <-5;
		do P5;
	}

	
	//la submersion est automatique (géré par reflex) mais on laisse la remise en état du monde
	user_command "Réparation des dommages de la submersion" {
		do remise_etat_monde;
		phase <-2;
		do P2;
	}
	

	// action pour que l'utilisateur lance la submersion
	//il y a probasub de chance d'avoir une sumbersion à chaque tour
	action submerger {
		if flip(0.5) {
			write "SUBMERSION !!!!!!!";
			do submerge;
			phase<-1;
			write "Les parcelles en bleues ont été submergées.";
			write "Vous devez réparer les dommages de la submersion";
			do P1;
		}
		else {
			write "Pas de submersion cette année...";
			phase <-2;
			do P2;
		}
}

}
/* ******************************************************************
 ******* fin global *******                                       ***
*********************************************************************/



/* ******************************************************************
 *******    TERRITOIRE                                      ***
*********************************************************************/

species territoire {
	//********************* PARTIE MAIRIE ******************************
	int id;
	float taux_impots <- 0.1;
	//budget initial de 100 kopec
	float budget<-100.0;
	int dommageMandat;
	int nbparcelle<-0;
	
	// securite moyenne
	float avgSecu;
	
	list<parcelle> mes_parcelles;
		
	// valeur ecologique moyenne
	float avgEcolo;

	//dommage total causé par une submersion
	float dommageTotal;
			
	// surface habitable = nombre de cellules terrestres * densite bati
	// pourcentage bati de l'ile
	float surface_habitable {
		sum ((parcelle where !each.is_sea) collect each.densite_bati)
	}

	//  20000 habitants en tout / surface habitable = population max par cellule
	// nb d'habitants par %age de surface batie 
	float densite_population {
		surface_habitable/20000
	}
	
	// affiche le budget du territoire
	action affiche_budget {
		write 'budget restant '+int(budget) + " kopecs";
	}
	
	action recueil_impot {
	ask mes_parcelles{
		do ComputeImpots;
		myself.budget <- myself.budget + impots;
	}
	do affiche_budget;
	}


	action CalculIndicateur {
	ask mes_parcelles{
		do ComputeValeurSecurite;
		do ComputeValeurEcolo;
		do ComputeValeurPolitique;
	}
	avgSecu <-mean(mes_parcelles collect each.valeurSecurite);
	avgEcolo <-mean(mes_parcelles collect each.valeurEcolo);
	indicateurPopularite <-mean(mes_parcelles collect each.valeurSatisfaction);
	}
	
	/**********************************
	 * *** CALCUL DES INDICATEURS *** *
	 **********************************/

	action ComputeDommageTotal {
	ask mes_parcelles {
	myself.dommageTotal<-myself.dommageTotal+dommage;
	}
	}	 
	 // popularite en fonction de la satisfaction ponderee de chaque cellule (satisfaction*densite population)
	float indicateurPopularite;
}


/***************************************
 * ******* GRILLE DE PARCELLES ******* *
 ***************************************/

grid parcelle width: 52 height: 90 neighbours: 8 frequency: 0 use_regular_agents: false use_individual_shapes: false use_neighbours_cache: false
{
	/***************************Variables pour flood****************************************/

	// altitude d'apres le MNT
	float altitude;

	// hauteur d'eau sur la cellule
	float water_height <- 0.0 min: 0.0;
	bool eau_present<- false;
	
	// hauteur du plus haut obstacle si plusieurs
	float obstacle_height <- 0.0;
	float altitude_obstacle<-0.0;
	float altitude_max<-0.0;
	
	// hauteur totale agreegee = altitude + hauteur eau
	float height;

	// cellules voisines (Moore, 8)
	list<parcelle> neighbour_cells;
	list<parcelle> neighbour_cells_far;
	
	//liste des parcelles de mer voisine de la parcelle
	list<parcelle> parcellesVoisinesMer;
	//est-ce qu'il y a des parcelles de mer à coté ?
	bool mer_proche <- false;


	// cellule mer / terre 
	bool is_sea <- false;

	bool celluleterrecote function: {((self neighbours_at 2) first_with not each.is_sea) != nil};
   	// parcelle de mer la plus proche et distance à la mer 
   	parcelle closestSea <- (sea_cells closest_to(self));
	
	// est-ce que la cellule a deja ete traitee dans la diffusion de l'eau
	bool already <- false;

	

	/****************************Variables interactions parcelles **********************/

	// 0 : pas de digue, 1 : petite digue, 2 : grosse digue
	int digue <- 0;
	
	//territoire auquel appartient la parcelle
	territoire mon_territoire;
	
	// il est possible de construire sur cette parcelle (pas en zone noire)
	bool constructible <- true;
	
	//dommage causé lors d'une submersion
	float dommage;
	
	//desnité du bati et nb d'habitant
	float densite_bati <- 0.0;
	float nbHabitants <-0.0;
	
	// il y a une maison sur cette parcelle
	bool maison;

	// valeur ecologique
	float valeurEcolo;
	
	//valorisation écologique de la parcelle
	int valorisationEcolo<-0;
	
	// valeur attractivite
	float valeurAttractivite;
	
	//valeur securite
	float valeurSecurite;
	float secuDigue <- 0.0;
		
	//valeur information : connaissance du risque
	int valeurInformation; 
	
	// valeur politique (accord avec actions du maire)
	float valeurPolitique;

	// impots donnes par cette parcelle a la mairie en fonction de sa population + attractivite (retombees touristiques)
	float impots;

		
	// valeur historique: submersion (nombre et hauteur max) 
	int nbSubmersion <- 0 ;
	float maxHauteur <- 0.0;
	
	// distance a la mer (pour securite-- et attractivite++)
	float distanceSea;
	
	
	int NbDigueVoisine;
	
	

// la satisfaction des habitants de cette parcelle est la somme des 3 indices (secu, ecolo, attractivite)
	float valeurSatisfaction;
	

	// satisfaction ponderee par la population - valeur entre 0 et 1000 (densite bati entre 1 et 100)
	float satisfactionPonderee function:{valeurSatisfaction * densite_bati};
	
	/*******************************************************
	 * *** ACTIONS DE CALCUL DE VARIABLES DE LA PARCELLE ***
	 *******************************************************/
	
	// - securite
	// secu augmente avec digues (++ si vraie digue, + si digue ecolo) et avec densite population et actions information
	// secu diminue avec proximite a la mer, et avec frequence/recence/gravite (ie hauteur d'eau) de la derniere inondation
	// - ecologie
	// ecolo augmente avec actions conservation et avec expropriation (direct par non constructibilite, indirect par diminution densite population)
	// ecolo diminue (--) avec digue standard, diminue un peu (-) avec digue ecolo, diminue avec densite population
	// - attractivite
	// attract augmente avec action promotion, avec proximite mer
	// attract diminue avec digues standard et avec densite population
	

	 
	//Calcul de la distance en m de la parcelle à la mer (reste inchangé pendant toute la partie)
	action ComputeDistanceSea  
	{
			closestSea <- (sea_cells closest_to(self)); 
			using topology(world) {
	   			distanceSea <- self distance_to closestSea;
	   		}
	}	
	
	// calcul de la valeur de securité à chaque tour 
	action  ComputeValeurSecurite 
	{	
		valeurSecurite <-0.0;
		
		// si aucune digue : securite 0
		if (digue=0) {secuDigue <- 0.0;}
		// si une ou plusieurs digues
		else {
			// s'il y a une vraie digue non ecolo : securite max
			if (digue=2) {secuDigue <- 10.0;}
			// sinon (digues ecolos / brise lame : securite moyenne
			else {secuDigue <- 5.0;}
		}

		// distance a la mer et présence digue
		valeurSecurite <- distanceSea/500+secuDigue; 
		  		   
		// si digue à coté et pas de digue sur notre parcelle, on se sent en insécurité
		list<parcelle> parcellesVoisinesDigue <- neighbour_cells_far where (each.digue>0);
		if (!empty(parcellesVoisinesDigue where (each.digue=2))) {valeurSecurite <- valeurSecurite-3;}
		if (!empty(parcellesVoisinesDigue where (each.digue=1))) {valeurSecurite <- valeurSecurite-1;}
		
		//Historique de submersion
		valeurSecurite <- valeurSecurite - nbSubmersion*5 - maxHauteur;
		
		valeurSecurite <- max([0, min([10,valeurSecurite])]);
	}
	

	
	action ComputeValeurEcolo {
		valeurEcolo<-0.0;
		
		//de base bvaleur ecolo max (10) pour les zones littorales et 8 pour les autres zones de l'ile
		if (mer_proche) {valeurEcolo<-10.0;}
		else {valeurEcolo<-5.0;}
		
		//diminution de la valeur écolo en fonction du bati
		if maison {valeurEcolo<-valeurEcolo-int(densite_bati/10);}
		
		//diminution de la valeur écolo en fonction des digues
		list<parcelle> parcellesVoisinesDigue <- neighbour_cells_far where (each.digue>0);
		if (!empty(parcellesVoisinesDigue where (each.digue=2))) {valeurEcolo <- valeurEcolo-6;}
		if (!empty(parcellesVoisinesDigue where (each.digue=1))) {valeurEcolo <- valeurEcolo-2;}
		
		//diminution de la valeur écolo en fonction des submersions passées
		valeurEcolo<-valeurEcolo-nbSubmersion;
		
		//augmentation des submersions en fonction de la valorisation environnementale de la parcelle
		valeurEcolo<-valeurEcolo+valorisationEcolo;
		
		valeurEcolo <- max([0, min([10,valeurEcolo])]);
	}

	//calcul de la valeur d'imposition de la parcelle
	action ComputeImpots{
		impots<-0.0;
		impots <- (mon_territoire.taux_impots * densite_bati)/10;
	}
	
	
	action ComputeValeurPolitique
	{
		valeurSatisfaction <-0.0;
		valeurSatisfaction <- (valeurSecurite + valeurEcolo + valeurPolitique) / 3; 	
	}
	
	
	


	/*********************************************************
	 * 			ACTIONS DE LA PARCELLE POUR LA SUBMERSION 	 *
	 *********************************************************/
	 
	 //action de transmission de la submersion
	action flow
	{
		// s'il y a de l'eau sur la cellule, il faut la diffuser
		if (water_height > 0)
		{
			// trouver la liste des voisins deja traites pour la diffusion
			list<parcelle> neighbour_cells_al <- neighbour_cells where (each.already);
			// si cette liste n'est pas vide
			if (!empty(neighbour_cells_al))
			{
				// demande au voisin de calculer leur hauteur
				ask neighbour_cells_al
				{
					//height correspnd à l'atitue de l'eau
					height <- altitude + water_height;
					//altitude obstacle, c'est l'atitude de la protection
					altitude_obstacle <- altitude+obstacle_height;
					//altitude max : altitude max entre les deux
					altitude_max <- max([height,altitude_obstacle]);
				}
				// la hauteur d'eau sur la présente cellule vaut altitude + hauteur d'eau
				height <- altitude + water_height;
				
				// cellules cibles de la diffusion : celles qui une hauteur d'eau plus basse que la cellule courante ou uen hauteur de digue plus basse
				
				list<parcelle> flow_cells <- (neighbour_cells_al where (height > each.altitude_max));
				
				// s'il y a des cellules plus basses
				if (!empty(flow_cells))
				{
					loop flow_cell over: shuffle(flow_cells) sort_by (each.altitude_max)
					{
						float water_flowing <- max([0.0, min([(height - flow_cell.altitude_obstacle),(height - flow_cell.height), water_height * diffusion_rate])]);
						water_height <- water_height - water_flowing;
						flow_cell.water_height <- flow_cell.water_height + water_flowing;
						height <- altitude + water_height;
						
					}
				}
			}
		}
		already <- true;
	}
	 
	//permet de tracer lors d'une submersion les parcelles touchées et le maximum d'eau qu'a connu la parcelle
	action releveStatSubm {
		if water_height>0 {
			eau_present<-true;
		}
		if water_height>maxHauteur {maxHauteur<-water_height;}  
	}
	 

	/************************************
	 * *** ACTIONS DE L'UTILISATEUR *** *
	 * *** JEU INTERACTIF           *** *
	 ************************************/ 
	
	// construction de digue non ecolo (protection++, ecolo--)
	user_command "construire une digue en béton"
	{ 
		if (mon_territoire.budget>=10) {
			digue<-2;
			obstacle_height<-6.0;
			mon_territoire.budget<-mon_territoire.budget-10;
			ask mon_territoire {
			do affiche_budget;	
			}
					}
		else {
			write "Vous n'avez plus assez de budget pour construire une digue en béton (coût de 10 kopecs)";
		}		
	}
	
	// construction d'une digue écolo (protection+, ecolo-)
	user_command "construire un brise lame"
	{
if (mon_territoire.budget>=6) {
			digue<-1;
			obstacle_height<-3.0;
			mon_territoire.budget<-mon_territoire.budget-6;
			ask mon_territoire {
			do affiche_budget;	
			}
		}
		else {
			write "Vous n'avez plus assez de budget pour construire un brise lame (coût de 6 kopecs)";
		}		
	}

	user_command "valoriser environnementalement la parcelle"
	{
if (mon_territoire.budget>=4) {
			valorisationEcolo<-valorisationEcolo+5;
			mon_territoire.budget<-mon_territoire.budget-4;
			ask mon_territoire {
			do affiche_budget;	
			}
		}
		else {
			write "Vous n'avez plus assez de budget pour construire un brise lame (coût de 4 kopecs)";
		}		
	}
	
	user_command "interdire construction" action: interdire_construction;
	action interdire_construction
	{
		constructible <- false;
		valeurPolitique <- valeurPolitique - densite_bati*10;
		densite_bati<-0.0;
		maison <-false;
	}

	action construire_maison
	{
		maison <- true;
	}



	//*************** DEFINITION DES CARTES DE VISUALISATION***************
	rgb ze_colour;
	//carte de base sur laquelle on peut agir
	aspect map_action
	{
		//rgb ze_colour<- #white;
		
		//dessin inconstructible : rond noir
		if (!constructible)
		{
			draw circle(150 # m) color: # black;
		}

		// maison = carre avec couleur variant du blanc au rouge selon la population
		if (maison)
		{
			draw square(150 # m) color: rgb(255,int(255-255*densite_bati/100),int(255-255*densite_bati/100));
		}

		//digue = triangle jaune
		if (digue=1){
			draw triangle(100 # m) color : # yellow;
		}
		if (digue=2){
			draw triangle(100 # m) color : # orange;
		}
	}



	// pour la carte de preservation ecologique des parcelles
	aspect ecolo
	{
		ze_colour <- # white;
		if (is_sea)
		{
			ze_colour <- # blue;
		}
		// degrade de vert pour valeur ecolo
		else		{
		ze_colour <- rgb(int(255 - 25.5 * valeurEcolo), 255, int(255 - 25.5 * valeurEcolo));
		}

		draw square(self.shape.perimeter) color: ze_colour;
	}
	
	// pour la carte de la securite des parcelles
	aspect secur
	{
		ze_colour <- # white;
		if (is_sea) {ze_colour <- # blue;}
		// degrade de rouge pour valeur secur
		else { ze_colour <- rgb(255, int(255 - 25.5 * valeurSecurite), int(255 - 25.5 * valeurSecurite)); }
		draw square(self.shape.perimeter) color : ze_colour;
	}
	
	// pour la carte de la satisfaction par parcelles
	aspect popu
	{
		ze_colour <- # white;
		if (is_sea) {ze_colour <- # blue;}
		// degrade de rouge pour valeur satsifaction
		else { ze_colour <- rgb(255, int(255 - 25.5 * valeurSatisfaction), int(255 - 25.5 * valeurSatisfaction)); }
		draw square(self.shape.perimeter) color : ze_colour;
	}

}






/********************
 * *** SIMULATION ***
 ********************/
experiment Displays type: gui
{
//Definition de quelques parametres
	output
	{
		//**********************CARTES***********************
		
		display map_action ambient_light: 100
		{
			grid parcelle triangulation : false lines : # black;
			species parcelle aspect: map_action;
		}

		// carte des valeurs ecolo en vert
		display map_ecologie ambient_light: 100
		{
			grid parcelle triangulation: false lines: # black;
			species parcelle aspect: ecolo;
		}
		
		// carte de securite en rouge
		display map_securite ambient_light: 100 
		{ 
			grid parcelle triangulation: false lines: # black ; 
			species parcelle aspect: secur ;
		}

		// carte de popularite en rouge
		display map_securite ambient_light: 100 
		{ 
			grid parcelle triangulation: false lines: # black ; 
			species parcelle aspect: popu ;
		}
	


		//**********************GRAPHS***********************

		display securite { 
			chart "Securite" type: series
			{
				ask territoire where (each.id>0) {
					data "sentiment de sécurité global" value: each.avgSecu color : #orange;
					data "limite acceptable" value:1 color : #red;
				}		
			}
		}		
		display ecologie {
			chart "Ecologie" type:series
			{
				ask territoire where (each.id>0) {
				data "valeur ecologique moyenne de l'ile" value: each.avgEcolo color: #green;
				data "limite acceptable" value:1 color : #red;
				}		
			}
		}
		display popularite {
			chart "Popularite" type:series
			{
				ask territoire where (each.id>0) {
				data "popularité du maire" value: each.indicateurPopularite color: #blue;
				data "limite acceptable" value:1 color : #red;
				}
			}
		}
		display dommages_cumules {
			chart "Dommages cumulés" type:series
			{
				ask territoire where (each.id>0) {
				data "dommages cumulés" value: each.dommageMandat color: #black;
				data "limite acceptable" value:100 color : #red;
				}
			}
		}
	} 

}
